package Thunderhorse::Controller;

use v5.40;
use Mooish::Base -standard;

use Thunderhorse::Context::Facade;
use URI;

extends 'Gears::Controller';
with 'Thunderhorse::Autoloadable';

sub make_facade ($self, $ctx)
{
	return Thunderhorse::Context::Facade->new(context => $ctx);
}

sub router ($self)
{
	my $router = $self->app->router;
	$router->set_controller($self);
	return $router;
}

sub _run_method ($self, $method, @args)
{
	die "no such method $method"
		unless ref $self;

	my $module_method = $self->app->extra_methods->{controller}{$method};

	die "no such method $method"
		unless $module_method;

	return $module_method->($self, @args);
}

sub _can_method ($self, $method)
{
	return exists $self->app->extra_methods->{controller}{$method};
}

sub url_for ($self, $name, @args)
{
	my $loc = $self->router->find($name);
	Gears::X::Thunderhorse->raise("no such route '$name'")
		unless defined $loc;

	return $loc->build(@args);
}

sub abs_url ($self, $url = '')
{
	return URI->new_abs(
		$url,
		$self->app->config->get('app_url', 'http://localhost:5000'),
	)->as_string;
}

sub abs_url_for ($self, $name, @args)
{
	return $self->abs_url($self->url_for($name, @args));
}

sub render_error ($self, $ctx, $code, $message = undef)
{
	$self->app->render_error($self, $ctx, $code, $message);
}

#####################
### HOOKS SECTION ###
#####################

sub _on_error ($self, @args)
{
	$self->app->_fire_hooks(error => $self, @args);
	return $self->on_error(@args);
}

sub on_error ($self, $ctx, $error)
{
	return $self->app->on_error($self, $ctx, $error);
}

