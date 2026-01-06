package Thunderhorse::Module;

use v5.40;
use Mooish::Base -standard;

extends 'Gears::Component';

has param 'config' => (
	isa => HashRef,
);

has field 'methods' => (
	isa => HashRef,
	default => sub {
		{
			controller => {},
		}
	},
);

has field 'middleware' => (
	isa => ArrayRef,
	default => sub { [] },
);

has field 'hooks' => (
	isa => HashRef,
	default => sub {
		{
			startup => [],
			shutdown => [],
			error => [],
		}
	},
);

# register new methods for various areas
sub register ($self, $for, $name, $code)
{
	my $area = $self->methods->{$for};
	Gears::X::Thunderhorse->raise("bad area '$for'")
		unless defined $area;

	Gears::X::Thunderhorse->raise("symbol '$name' already exists in area '$for'")
		if exists $area->{$name};

	$area->{$name} = $code;
	return $self;
}

sub wrap ($self, $mw)
{
	push $self->middleware->@*, $mw;
	return $self;
}

sub hook ($self, $hook, $handler)
{
	push $self->hooks->{$hook}->@*, $handler;
	return $self;
}

