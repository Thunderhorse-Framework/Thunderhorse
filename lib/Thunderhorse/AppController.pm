package Thunderhorse::AppController;

use v5.40;
use Mooish::Base -standard;

extends 'Thunderhorse::Controller';
with 'Thunderhorse::Autoloadable';

sub _run_method ($self, $method, @args)
{
	die "no such method $method"
		unless ref $self;
	return $self->app->$method(@args);
}

sub _can_method ($self, $method)
{
	return $self->app->can($method);
}

