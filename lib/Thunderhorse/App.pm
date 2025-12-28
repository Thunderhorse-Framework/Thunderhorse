package Thunderhorse::App;

use v5.40;
use Mooish::Base -standard;

use Gears qw(load_component get_component_name);
use Thunderhorse::Context;
use Thunderhorse::Router;
use Thunderhorse::Controller;
use Thunderhorse::AppController;

use IO::Async::Loop;
use Future::AsyncAwait;

extends 'Gears::App';

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

sub _build_app_controller ($self)
{
	return $self->_build_controller('Thunderhorse::AppController');
}

sub router ($self)
{
	my $router = $self->_router;
	$router->set_controller($self->controller);
	return $router;
}

sub load_module ($self, $module_class, %args)
{
	my $module = load_component(get_component_name($module_class, 'Thunderhorse::Module'))
		->new(app => $self, config => \%args);

	# Merge module's registered methods into app's collection
	foreach my $area (keys $module->registered->%*) {
		$self->extra_methods->{$area}->%* = (
			$self->extra_methods->{$area}->%*,
			$module->registered->{$area}->%*
		);
	}

	push $self->modules->@*, $module;
	return $self;
}

async sub pagi ($self, $scope, $receive, $send)
{
	my $scope_type = $scope->{type};
	die 'Unsupported scope type'
		unless $scope_type =~ m/^(http|sse|websocket)$/;

	$scope = {$scope->%*};
	my $ctx = Thunderhorse::Context->new(
		app => $self,
		pagi => [$scope, $receive, $send],
	);

	$scope->{thunderhorse} = $ctx;

	my $req = $ctx->req;
	my $router = $self->_router;
	my $matches = $router->match($req->path, $req->method);

	await $self->pagi_loop($ctx, $matches->@*);

	if (!$ctx->is_consumed) {
		await $ctx->res->status(404)->text('Not Found');
	}

	return;
}

async sub pagi_loop ($self, $ctx, @matches)
{
	my @pagi = $ctx->pagi->@*;

	foreach my $match (@matches) {
		# is this a bridge? If yes, take first element (the bridge location).
		# It is guaranteed to be a match, not an array
		my $loc = (ref $match eq 'ARRAY' ? $match->[0] : $match)->location;

		# $ctx->match may be an array if this is a bridge. Location handler
		# takes care of that
		$ctx->set_match($match);

		# execute location handler (PAGI application)
		await $loc->pagi_app->(@pagi);
		last if $ctx->is_consumed;
	}
}

sub run ($self)
{
	return sub (@args) {
		return $self->pagi(@args);
	}
}

