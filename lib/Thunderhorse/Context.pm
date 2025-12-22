package Thunderhorse::Context;

use v5.40;
use Mooish::Base -standard;

use Devel::StrictMode;

use Thunderhorse::Request;
use Thunderhorse::Response;

extends 'Gears::Context';

has field 'pagi' => (
	(STRICT ? (isa => Tuple [HashRef, CodeRef, CodeRef]) : ()),
	writer => 1,
);

has field 'req' => (
	(STRICT ? (isa => InstanceOf ['Thunderhorse::Request']) : ()),
	default => sub ($self) { Thunderhorse::Request->new(context => $self) },
);

has field 'res' => (
	(STRICT ? (isa => InstanceOf ['Thunderhorse::Response']) : ()),
	default => sub ($self) { Thunderhorse::Response->new(context => $self) },
);

sub scope ($self)
{
	return $self->pagi->[0];
}

sub receiver ($self)
{
	return $self->pagi->[1];
}

sub sender ($self)
{
	return $self->pagi->[2];
}

