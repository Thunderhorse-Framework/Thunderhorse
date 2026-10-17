package Thunderhorse::Response;

use v5.40;
use Mooish::Base -standard;

use Devel::StrictMode;
use Cookie::Baker qw(bake_cookie);
use PAGI::Headers;
use PAGI::Response qw(response);
use Gears::X::Thunderhorse;

with 'Thunderhorse::Message';

has field '_status' => (
	(STRICT ? (isa => PositiveInt) : ()),
	writer => 1,
	predicate => -public,
);

has field 'headers' => (
	(STRICT ? (isa => ArrayRef) : ()),
	default => sub { [] },
);

has field '_type' => (
	(STRICT ? (isa => Str) : ()),
	writer => 1,
	predicate => 1,
);

has field '_args' => (
	(STRICT ? (isa => ArrayRef) : ()),
	writer => 1,
	default => sub { [] },
);

has field '_body_source' => (
	(STRICT ? (isa => Defined) : ()),
	writer => 1,
	predicate => -public,
);

sub status ($self, @maybe_status)
{
	if (@maybe_status) {
		$self->_set_status($maybe_status[0]);
		return $self;
	}
	else {
		return $self->_status;
	}
	return $self;
}

sub status_try ($self, $new_status)
{
	$self->_set_status($new_status)
		unless $self->has_status;
	return $self;
}

sub header ($self, $name, $value)
{
	push $self->headers->@*, lc $name, $value;
	return $self;
}

sub header_try ($self, $name, $value)
{
	$self->header($name, $value)
		unless $self->has_header($name);
	return $self;
}

sub has_header ($self, $name)
{
	$name = lc $name;
	foreach my ($this_name, $value) ($self->headers->@*) {
		return true if $this_name eq $name;
	}

	return false;
}

sub remove_header ($self, $name)
{
	$name = lc $name;
	my @new_headers;
	foreach my ($this_name, $value) ($self->headers->@*) {
		next if $this_name eq $name;
		push @new_headers, $this_name, $value;
	}

	$self->headers->@* = @new_headers;
	return $self;
}

sub content_type ($self, $value)
{
	$self->header('content-type', $value);
	return $self;
}

sub content_type_try ($self, $value)
{
	$self->content_type($value)
		unless $self->has_content_type;

	return $self;
}

sub has_content_type ($self)
{
	return $self->has_header('content-type');
}

sub cookie ($self, $name, $value, %options)
{
	my %cookie_data = (
		value => $value,
		path => $options{path} // '/',
		(defined $options{domain} ? (domain => $options{domain}) : ()),
		(defined $options{expires} ? (expires => $options{expires}) : ()),
		(defined $options{max_age} ? ('max-age' => $options{max_age}) : ()),
		(defined $options{samesite} ? (samesite => $options{samesite}) : ()),
		($options{secure} ? (secure => $options{secure}) : ()),
		($options{httponly} ? (httponly => $options{httponly}) : ()),
	);

    return $self->header('set-cookie', bake_cookie $name, %cookie_data);
}

sub delete_cookie ($self, $name, %options)
{
	return $self->cookie($name, '', %options, max_age => 0, expires => 0);
}

sub _check_set_type ($self, $type)
{
	if (!$self->_has_type) {
		$self->_set_type($type);
		return;
	}

	Gears::X::Thunderhorse->raise(
		sprintf 'trying to set response type to %s, but %s was set already',
		$type,
		$self->_type,
	);
}

sub text ($self, $content)
{
	$self->_check_set_type('Text');
	$self->_set_body_source('' . $content);
	return $self;
}

sub html ($self, $content)
{
	$self->_check_set_type('HTML');
	$self->_set_body_source('' . $content);
	return $self;
}

sub json ($self, $content)
{
	$self->_check_set_type('JSON');
	$self->_set_body_source($content);
	return $self;
}

sub redirect ($self, $url, $status = 302)
{
	$self->status_try($status);
	$self->_check_set_type('Redirect');
	$self->_set_body_source($url);
	return $self;
}

sub file ($self, $path, @options)
{
	$self->_check_set_type('Redirect');
	$self->_set_args(\@options);
	$self->_set_body_source($path);
	return $self;
}

sub stream ($self, $producer, @options)
{
	$self->_check_set_type('Stream');
	$self->_set_args(\@options);
	$self->_set_body_source($producer);
	return $self;
}

sub body_source ($self, $content)
{
	$self->_set_body_source($content);
	return $self;
}

sub update
{
	# no need to do anything - no superclass
}

sub _allows_empty_body ($self, $status)
{
	# HTTP protocol hardcodes - these statuses can have empty bodies
	return $status < 200
		|| $status == 204
		|| ($status >= 300 && $status < 400);
}

sub is_ready ($self)
{
	return true if $self->has_body_source;

	return $self->_allows_empty_body($self->status)
		if $self->has_status;

	return false;
}

sub finalize ($self)
{
	my $status = $self->_status;

	if (my $type = $self->_type) {
		return response(
			$type,
			$self->_body_source,
			(defined $status ? (status => $status) : ()),
			headers => $self->headers,
			$self->_args->@*
		);
	}
	elsif (my $body_source = $self->_body_source) {
		return PAGI::Response->new(
			$body_source,
			(defined $status ? (status => $status) : ()),
			headers => $self->headers,
		);
	}
	elsif (defined $status && $self->_allows_empty_body($status)) {
		return response(
			'Empty',
			status => $status,
			headers => $self->headers,
		);
	}
	else {
		Gears::X::Thunderhorse->raise('attempt to finalize a response prematurely');
	}
}

__END__

=head1 NAME

Thunderhorse::Response - Response builder for Thunderhorse

=head1 SYNOPSIS

	async sub show ($self, $ctx, $id)
	{
		$ctx->res->text("Hello World");
		$ctx->res->json({data => 'value'});
		$ctx->res->redirect('/login');
	}

=head1 DESCRIPTION

Thunderhorse::Response is a thin wrapper around L<PAGI::Response> that
integrates with L<Thunderhorse::Context>. It provides a fluent interface for
building HTTP responses, including JSON, HTML, redirects, and file
downloads.

This class extends L<PAGI::Response> and mixes in C<Thunderhorse::Message> to
provide context integration.

=head1 INTERFACE

Inherits all interface from L<PAGI::Response>, and adds the interface
documented below.

=head2 Attributes

=head3 context

The L<Thunderhorse::Context> object for this request (weakened).

I<Required in the constructor>

=head2 Methods

=head3 new

	$object = $class->new(%args)

Standard Mooish constructor. Consult L</Attributes> section for available
constructor arguments.

=head3 update

	$res->update($scope, $receive, $send)

Updates the internal PAGI scope. Called automatically when the context's PAGI
tuple changes via setter of L<Thunderhorse::Context/pagi>.

=head3 is_ready

	$bool = $res->is_ready()

Returns whether this response is ready as far as Thunderhorse is concerned.
Responses which are ready will cause the context to become consumed after the
route handler returns.

Response is ready if it has a body, or if it has a status which does not
require body like C<204 No Content> or C<3XX>.

=head1 SEE ALSO

L<Thunderhorse>, L<PAGI::Response>, L<Thunderhorse::Context>

