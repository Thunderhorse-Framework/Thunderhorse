package Thunderhorse::Message;

use v5.40;
use Mooish::Base -standard;

use HTTP::Headers::Fast;
use Devel::StrictMode;

has param 'context' => (
	(STRICT ? (isa => InstanceOf ['Thunderhorse::Context']) : ()),
	weak_ref => 1,
);

has field 'headers' => (
	(STRICT ? (isa => InstanceOf ['HTTP::Headers::Fast']) : ()),
	lazy => 1,
);

sub mutable ($self)
{
	...;
}

sub _build_headers ($self)
{
	return HTTP::Headers::Fast->new;
}

sub _headers_from_pagi ($self, $headers)
{
	# TODO
}

sub _headers_to_pagi ($self)
{
	my $headers = $self->headers;

	# stolen and adjusted from HTTP::Headers::flatten
	# TODO: ensure bytes (here or on the level of adding headers)
	return [
		map {
			my $k = $_;
			map {
				[lc $k => $_]
			} $headers->header($_);
		} $headers->header_field_names
	];
}

sub header ($self, $name, $value = undef)
{
	return $self->headers->header($name)
		unless defined $value;

	Gears::X->raise('this message is immutable')
		unless $self->mutable;

	$self->headers->header($name, $value);
	return $self;
}

sub content_type ($self, $type = undef)
{
	return $self->header('Content-Type', $type);
}

