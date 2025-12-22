package Thunderhorse::Controller;

use v5.40;
use Mooish::Base -standard;

extends 'Gears::Controller';

sub router ($self)
{
	my $router = $self->app->router;
	$router->set_controller($self);
	return $router;
}

