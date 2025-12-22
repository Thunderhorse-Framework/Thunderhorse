package Thunderhorse::Request;

use v5.40;
use Mooish::Base -standard;

use Devel::StrictMode;

extends 'Thunderhorse::Message';

sub mutable { false }

sub path ($self)
{
	return $self->context->scope->{path};
}

sub method ($self)
{
	return $self->context->scope->{method};
}

