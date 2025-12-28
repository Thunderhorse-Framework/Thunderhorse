package Thunderhorse::Module;

use v5.40;
use Mooish::Base -standard;

extends 'Gears::Component';

has param 'config' => (
	isa => HashRef,
);

has field 'registered' => (
	isa => HashRef,
	default => sub {
		{
			controller => {},
		}
	},
);

# register new methods for various areas
sub register ($self, $for, $name, $code)
{
	my $area = $self->registered->{$for};
	Gears::X::Thunderhorse->raise("bad area '$for'")
		unless defined $area;

	Gears::X::Thunderhorse->raise("symbol '$name' already exists in area '$for'")
		if exists $area->{$name};

	$area->{$name} = $code;
}

