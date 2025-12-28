package Thunderhorse::Controller;

use v5.40;
use Mooish::Base -standard;

use Thunderhorse::Context::Facade;

extends 'Gears::Controller';

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

