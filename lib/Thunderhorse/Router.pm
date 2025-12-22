package Thunderhorse::Router;

use v5.40;
use Mooish::Base -standard;

use Thunderhorse::Router::Location;
use Thunderhorse::Router::Match;

extends 'Gears::Router';

has field 'controller' => (
	isa => InstanceOf ['Thunderhorse::Controller'],
	writer => 1,
);

has option 'cache' => (
	isa => HasMethods ['get', 'set', 'clear'],
);

has field '_find_cache' => (
	isa => HashRef,
	default => sub { {} },
);

has field '_last_route_id' => (
	isa => PositiveOrZeroInt,
	default => 0,
	writer => 1,
);

sub _build_location ($self, %args)
{
	return Thunderhorse::Router::Location->new(
		%args,
		controller => $self->controller,
	);
}

sub _build_match ($self, $location, $match_data)
{
	return Thunderhorse::Router::Match->new(
		location => $location->name,
		matched => $match_data,
	);
}

sub _match_level ($self, $locations, @args)
{
	my @result = $self->SUPER::_match_level($locations, @args);

	my $bridge = shift @result;
	@result =
		map { $_->[0] }
		sort { $a->[1] <=> $b->[1] }
		map { [$_, ref eq 'ARRAY' ? $_->[0]->order : $_->order] }
		@result;

	return ($bridge, @result);
}

sub match ($self, $method, $path)
{
	return $self->SUPER::match($method, $path)
		unless $self->has_cache;

	my $key = "$method;$path";
	my $result = $self->cache->get($key);
	return $result if $result;

	$self->cache->set($key, $self->SUPER::match($path));
	return $result;
}

sub clear ($self)
{
	$self->cache->clear
		if $self->has_cache;

	$self->_find_cache->%* = ();

	return $self->SUPER::clear;
}

sub get_next_route_id ($self)
{
	my $last = $self->_last_route_id;
	$self->_set_last_route_id(++$last);

	return $last;
}

sub _find ($self, $name, $locations)
{
	foreach my $location ($locations->@*) {
		return $location
			if $location->name eq $name;

		if ($location->locations->@*) {
			my $found = $self->_find($name, $location->locations);
			return $found if defined $found;
		}
	}

	return undef;
}

sub find ($self, $name)
{
	return $self->_find_cache->{$name} //= $self->_find($name, $self->locations);
}

