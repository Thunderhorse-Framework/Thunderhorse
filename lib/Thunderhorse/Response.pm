package Thunderhorse::Response;

use v5.40;
use Mooish::Base -standard;

use HTTP::Headers::Fast;
use Devel::StrictMode;

extends 'Thunderhorse::Message';

has param 'context' => (
	(STRICT ? (isa => InstanceOf ['Thunderhorse::Context']) : ()),
	weak_ref => 1,
);

has field '_code' => (
	(STRICT ? (isa => PositiveInt) : ()),
	writer => 1,
);

has field '_rendered' => (
	(STRICT ? (isa => Bool) : ()),
	writer => 1,
	default => false,
);

# TODO: encoding

sub mutable { true }

sub _render ($self, $content)
{
	my $send = $self->context->sender;

	return $send->(
		{
			type => 'http.response.start',
			status => $self->_code,
			headers => $self->_headers_to_pagi,
		}
	)->then(
		sub {
			$send->(
				{
					type => 'http.response.body',
					body => $content,
					more => 0,
				}
			);
		}
	)->then(
		sub {
			$self->_set_rendered(true);
		}
	);
}

sub code ($self, $code = undef)
{
	return $self->_code
		unless defined $code;

	$self->_set_code($code);
	return $self;
}

sub header ($self, $name, $value = undef)
{
	return $self->headers->header($name)
		unless defined $value;

	$self->headers->header($name, $value);
	return $self;
}

sub content_type ($self, $type = undef)
{
	return $self->header('Content-Type', $type);
}

sub rendered ($self, $value = undef)
{
	return $self->_rendered
		unless defined $value;

	$self->_set_rendered($value);
	return $self;
}

sub render ($self, $type, $content)
{
	if ($type eq 'html') {
		return $self->content_type('text/html')->_render($content);
	}
	elsif ($type eq 'text') {
		return $self->content_type('text/plain')->_render($content);
	}

	# TODO: other types based on encoders, probably
	Gears::X->raise("unknown render type: $type");
}

