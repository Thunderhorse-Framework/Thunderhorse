package Thunderhorse::Response;

use v5.40;
use Mooish::Base -standard;

use Scalar::Util qw(blessed refaddr);
use PAGI::Response qw(response status_forbids_body);

with 'Thunderhorse::Message';

my @metadata_methods = qw(status status_try has_status header header_all header_try has_header
	remove_header headers content_type content_type_try has_content_type cookie delete_cookie);

# The status, headers and cookies a handler sets are staged on PAGI-Tools'
# empty response value, whose own metadata methods this response delegates
# to; the body, and the class that sends it, come at finalize.
has field '_response' => (default => sub { PAGI::Response->new }, handles => \@metadata_methods);
has field '_content' => (writer => 1, predicate => 1);    # [class, content, @options]

# A delegated setter returns the staged value; return this response instead,
# so handler chains such as $res->status(201)->text(...) keep working.
around \@metadata_methods => sub ($orig, $self, @args) {
	my $got = $self->$orig(@args);
	return blessed($got) && refaddr($got) == refaddr($self->_response) ? $self : $got;
};

sub text ($self, @args)
{
	return $self->_choose('Text', @args);
}

sub html ($self, @args)
{
	return $self->_choose('HTML', @args);
}

sub json ($self, @args)
{
	return $self->_choose('JSON', @args);
}

sub file ($self, @args)
{
	return $self->_choose('File', @args);
}

sub stream ($self, @args)
{
	return $self->_choose('Stream', @args);
}

# Not like the others: the status is a positional argument, as in the 0.002
# builder, and like that builder it replaces any status set earlier.
sub redirect ($self, $url, $status = 302)
{
	return $self->status($status)->_choose('Redirect', $url);
}

# Records the response class and its content for finalize.
sub _choose ($self, $class, $content, @options)
{
	$self->_set_content([$class, $content, @options]);
	return $self;
}

sub update ($self, $scope, $receive, $send)
{
	# nothing to rebind: the staged value holds no scope
}

sub is_ready ($self)
{
	return true if $self->_has_content;
	return false unless $self->has_status;

	# a status that forbids content, or a redirect, may go without a body
	my $status = $self->status;
	return status_forbids_body($status) || ($status >= 300 && $status < 400);
}

sub finalize ($self)
{
	my ($class, $content, @options) = $self->_has_content ? $self->_content->@* : ('+PAGI::Response');
	return response($class, $content,
		($self->has_status ? (status => $self->status) : ()),
		headers => $self->headers, @options);
}

__END__

=head1 NAME

Thunderhorse::Response - Response wrapper for Thunderhorse

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

It mixes in C<Thunderhorse::Message> to provide context integration. What a
handler sets is staged on an empty L<PAGI::Response>, and L</finalize> builds
the response from it.

=head1 INTERFACE

The status, header, content type and cookie methods are L<PAGI::Response>'s
(C<status>, C<status_try>, C<has_status>, C<header>, C<header_all>,
C<header_try>, C<has_header>, C<remove_header>, C<headers>, C<content_type>,
C<content_type_try>, C<has_content_type>, C<cookie>, C<delete_cookie>), applied
to the staged value; setters return this response, so calls chain. The rest of
the interface is documented below.

=head2 Attributes

=head3 context

The L<Thunderhorse::Context> object for this request (weakened).

I<Required in the constructor>

=head2 Methods

=head3 new

	$object = $class->new(%args)

Standard Mooish constructor. Consult L</Attributes> section for available
constructor arguments.

=head3 text, html, json, file, stream

	$res = $res->text($string, %options)
	$res = $res->json($data, %options)

Choose the content and the L<PAGI::Response> class that sends it:
L<PAGI::Response::Text>, L<PAGI::Response::HTML>, L<PAGI::Response::JSON>,
L<PAGI::Response::File> (a path) or L<PAGI::Response::Stream> (a producer).
C<%options> are that class's own options. The last call wins.

=head3 redirect

	$res = $res->redirect($url, $status = 302)

Chooses a L<PAGI::Response::Redirect> to C<$url> with C<$status>, which
replaces any status set earlier.

=head3 update

	$res->update($scope, $receive, $send)

Called when the context's PAGI tuple changes via setter of
L<Thunderhorse::Context/pagi>. The response holds no scope, so there is nothing
to rebind.

=head3 is_ready

	$bool = $res->is_ready()

Returns whether this response is ready as far as Thunderhorse is concerned.
Responses which are ready will cause the context to become consumed after the
route handler returns.

Response is ready if it has a body, or if it has a status that forbids one
(1xx, C<204>, C<205>, C<304>; see L<PAGI::Response/status_forbids_body>) or is a
C<3XX> redirect.

=head3 finalize

	$response = $res->finalize()

Builds the L<PAGI::Response> for what was staged: the class chosen by C<text>,
C<html> and the others, with the status and headers set. With no class chosen
it is the base class with an empty body, so L<Thunderhorse::Context/send_res>
can always send. L<Thunderhorse::Context/try_send_res> checks L</is_ready>
first.

=head1 SEE ALSO

L<Thunderhorse>, L<PAGI::Response>, L<Thunderhorse::Context>

