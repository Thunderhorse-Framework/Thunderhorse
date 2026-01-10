package Thunderhorse::App;

use v5.40;
use Mooish::Base -standard;

use Thunderhorse qw(pagi_loop);
use Thunderhorse::Config;
use Gears qw(load_component get_component_name);
use Thunderhorse::Context;
use Thunderhorse::Router;
use Thunderhorse::Controller;
use Thunderhorse::AppController;
use Path::Tiny;

use HTTP::Status qw(status_message);
use IO::Async::Loop;
use Future::AsyncAwait;
use PAGI::Utils qw(handle_lifespan);
use FindBin;

extends 'Gears::App';

has param 'path' => (
	coerce => (InstanceOf ['Path::Tiny'])
		->plus_coercions(Str, q{ Path::Tiny::path($_) }),
	default => sub { $FindBin::Bin },
);

has param 'env' => (
	isa => Enum ['production', 'development', 'test'],
	default => sub { $ENV{PAGI_ENV} // 'production' },
);

has param 'initial_config' => (
	isa => Str | HashRef,
	default => sub { {} },
);

has field 'loop' => (
	isa => InstanceOf ['IO::Async::Loop'],
	default => sub { IO::Async::Loop->new },
);

# the base app controller
has field 'controller' => (
	isa => InstanceOf ['Thunderhorse::Controller'],
	lazy => '_build_app_controller',
);

has extended 'router' => (
	reader => '_router',
	isa => InstanceOf ['Thunderhorse::Router'],
	default => sub { Thunderhorse::Router->new },
);

has extended 'config' => (
	builder => 1,
);

has field 'modules' => (
	isa => ArrayRef,
	default => sub { [] },
);

has field 'extra_methods' => (
	isa => HashRef,
	default => sub {
		{
			controller => {},
		}
	},
);

has field 'extra_middleware' => (
	isa => ArrayRef,
	default => sub { [] },
);

has field 'extra_hooks' => (
	isa => HashRef,
	default => sub {
		{
			startup => [],
			shutdown => [],
			error => [],
		}
	},
);

#############################
### BOOTSTRAPPING SECTION ###
#############################

sub BUILD ($self, $)
{
	$self->late_configure;
}

sub _build_config ($self)
{
	my $conf = Thunderhorse::Config->new;
	foreach my $reader ($conf->readers->@*) {
		next unless $reader isa 'Gears::Config::Reader::PerlScript';

		# make app available from .pl config files
		$reader->declared_vars->%* = (
			$reader->declared_vars->%*,
			app => $self,
		);
	}

	return $conf;
}

sub _build_app_controller ($self)
{
	return $self->_build_controller('Thunderhorse::AppController');
}

sub _build_context ($self, @pagi)
{
	return Thunderhorse::Context->new(
		app => $self,
		pagi => \@pagi,
	);
}

sub is_production ($self)
{
	return $self->env eq 'production';
}

sub router ($self)
{
	my $router = $self->_router;
	$router->set_controller($self->controller);
	return $router;
}

sub configure ($self)
{
	my $config = $self->config;

	my $preconf = $self->initial_config;
	if (!ref $preconf) {
		$config->load_from_files($self->path->child($preconf), $self->env);
	}
	else {
		$config->add(var => $preconf);
	}

	# TODO: module dependencies and ordering
	my %modules = $config->get('modules', {})->%*;
	foreach my $module_name (sort keys %modules) {
		$self->load_module($module_name, $modules{$module_name});
	}
}

sub late_configure ($self)
{
	foreach my $controller ($self->config->get('controllers', [])->@*) {
		$self->load_controller($controller);
	}
}

sub load_module ($self, $module_class, $args = {})
{
	my $module = load_component(get_component_name($module_class, 'Thunderhorse::Module'))
		->new(app => $self, config => $args);

	foreach my $area (keys $module->methods->%*) {
		$self->extra_methods->{$area}->%* = (
			$self->extra_methods->{$area}->%*,
			$module->methods->{$area}->%*,
		);
	}

	foreach my $hook (keys $module->hooks->%*) {
		$self->extra_hooks->{$hook}->@* = (
			$self->extra_hooks->{$hook}->@*,
			$module->hooks->{$hook}->@*,
		);
	}

	$self->extra_middleware->@* = (
		$self->extra_middleware->@*,
		$module->middleware->@*,
	);

	push $self->modules->@*, $module;
	return $self;
}

###################################
### PAGI IMPLEMENTATION SECTION ###
###################################

async sub pagi ($self, $scope, $receive, $send)
{
	my $scope_type = $scope->{type};

	return await handle_lifespan(
		$scope, $receive, $send,
		startup => sub { $self->_on_startup(@_) },
		shutdown => sub { $self->_on_shutdown(@_) },
	) if $scope_type eq 'lifespan';

	die 'Unsupported scope type'
		unless $scope_type =~ m/^(http|sse|websocket)$/;

	$scope = {$scope->%*};
	my $ctx = $self->_build_context($scope, $receive, $send);

	$scope->{thunderhorse} = $ctx;

	my $req = $ctx->req;
	my $router = $self->_router;
	my $action = lc join '.', grep { defined } ($scope_type, $req->method);
	my $matches = $router->match($req->path, $action);

	await pagi_loop($ctx, $matches->@*);

	if (!$ctx->is_consumed) {
		await $self->render_error(undef, $ctx, 404);
	}

	return;
}

sub run ($self)
{
	# do not turn into PAGI application if run by a thunderhorse script
	return $self if $ENV{THUNDERHORSE_SCRIPT};

	my $pagi = sub (@args) {
		return $self->pagi(@args);
	};

	foreach my $mw ($self->extra_middleware->@*) {
		if (ref $mw eq 'CODE') {
			$pagi = $mw->($pagi);
		}
		elsif ($mw isa 'PAGI::Middleware') {
			$pagi = $mw->wrap($pagi);
		}
		else {
			Gears::X::Thunderhorse->raise('bad middleware, not CODE or PAGI::Middleware');
		}
	}

	return $pagi;
}

async sub render_error ($self, $controller, $ctx, $code, $message = undef)
{
	$message = defined $message && !$self->is_production ? $message : status_message($code);
	await $ctx->res->status($code)->text($message);
}

#####################
### HOOKS SECTION ###
#####################

sub hook ($self, $hook, $handler)
{
	push $self->extra_hooks->{$hook}->@*, $handler;
	return $self;
}

sub _fire_hooks ($self, $hook, @args)
{
	foreach my $handler ($self->extra_hooks->{$hook}->@*) {
		$handler->(@args);
	}
}

sub _on_startup ($self, @args)
{
	$self->_fire_hooks(startup => @args);
	return $self->on_startup(@args);
}

async sub on_startup ($self, $state)
{
}

sub _on_shutdown ($self, @args)
{
	$self->_fire_hooks(shutdown => @args);
	return $self->on_shutdown(@args);
}

async sub on_shutdown ($self, $state)
{
}

async sub on_error ($self, $controller, $ctx, $error)
{
	my $code = $error isa 'Gears::X::HTTP' ? $error->code : 500;
	await +($controller // $self->controller)->render_error($ctx, $code, $error);
}

