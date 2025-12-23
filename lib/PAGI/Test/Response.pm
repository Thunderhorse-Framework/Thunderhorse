package PAGI::Test::Response;

use strict;
use warnings;

use Carp qw(croak);

sub new {
    my ($class, %args) = @_;
    return bless {
        status  => $args{status},
        headers => $args{headers} // [],
        body    => $args{body} // '',
        events  => $args{events} // [],
        error   => $args{error},
    }, $class;
}

sub status  { shift->{status} }
sub headers { shift->{headers} }
sub body    { shift->{body} }
sub events  { @{shift->{events}} }
sub error   { shift->{error} }

sub is_success  { my $s = shift->status; $s && $s >= 200 && $s < 300 }
sub is_redirect { my $s = shift->status; $s && $s >= 300 && $s < 400 }
sub is_error    { my $s = shift->status; $s && $s >= 400 }

sub header {
    my ($self, $name) = @_;
    $name = lc($name);
    my $value;
    for my $pair (@{$self->{headers}}) {
        if (lc($pair->[0]) eq $name) {
            $value = $pair->[1];
        }
    }
    return $value;
}

sub header_all {
    my ($self, $name) = @_;
    $name = lc($name);
    my @values;
    for my $pair (@{$self->{headers}}) {
        if (lc($pair->[0]) eq $name) {
            push @values, $pair->[1];
        }
    }
    return @values;
}

sub decoded_body {
    my $self = shift;
    require Encode;
    return Encode::decode('UTF-8', $self->{body}, Encode::FB_CROAK());
}

sub json {
    my $self = shift;
    require JSON::PP;
    return JSON::PP::decode_json($self->{body});
}

1;

__END__

=head1 NAME

PAGI::Test::Response - Response object for PAGI::Test

=head1 DESCRIPTION

Returned by PAGI::Test::request() methods. Provides convenient access to
response status, headers, and body.

=head1 METHODS

=head2 status

    my $code = $res->status;

HTTP status code.

=head2 is_success

    if ($res->is_success) { ... }

Returns true if status is 2xx.

=head2 is_redirect

    if ($res->is_redirect) { ... }

Returns true if status is 3xx.

=head2 is_error

    if ($res->is_error) { ... }

Returns true if status is 4xx or 5xx.

=head2 headers

    my $headers = $res->headers;  # arrayref of [name, value]

All response headers.

=head2 header

    my $value = $res->header('content-type');

Get a single header value (case-insensitive). Returns the last value if
the header appears multiple times.

=head2 header_all

    my @values = $res->header_all('set-cookie');

Get all values for a header.

=head2 body

    my $body = $res->body;

Response body as a string.

=head2 decoded_body

    my $text = $res->decoded_body;

Response body decoded as UTF-8. Dies if body contains invalid UTF-8.

=head2 json

    my $data = $res->json;

Parse response body as JSON. Dies on parse error.

=head2 events

    my @events = $res->events;

Returns all send events captured during request processing. Useful for
debugging or testing protocol compliance.

=head2 error

    my $error = $res->error;

Returns the error message if the app threw an exception, undef otherwise.

