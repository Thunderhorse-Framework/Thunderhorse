package Thunderhorse::Controller;

use v5.40;
use Mooish::Base -standard;

use Thunderhorse::Context::Facade;

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

