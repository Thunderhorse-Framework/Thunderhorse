package PAGI::Test;

use strict;
use warnings;

use Future::AsyncAwait;
use IO::Async::Loop;
use PAGI::Test::Response;
use Carp qw(croak);

our $VERSION = '0.001';

sub new {
    my ($class, %args) = @_;

    my $app = delete $args{app} or croak "app is required";
    croak "app must be a coderef" unless ref $app eq 'CODE';

    my $self = bless {
        app        => $app,
        loop       => delete $args{loop} // IO::Async::Loop->new,
        extensions => delete $args{extensions} // {},
        state      => delete $args{state} // {},
        lifespan_started => 0,
    }, $class;

    croak "Unknown arguments: " . join(', ', keys %args) if %args;

    return $self;
}

async sub request {
    my ($self, $method, $path, %opts) = @_;

    croak "method is required" unless defined $method;
    croak "path is required" unless defined $path;

    # Parse path and query string
    my ($clean_path, $path_query) = split /\?/, $path, 2;

    # Build query string
    my @query_parts;
    push @query_parts, $path_query if defined $path_query;

    if (my $query = delete $opts{query}) {
        for my $key (sort keys %$query) {
            my $value = $query->{$key};
            my @values = ref $value eq 'ARRAY' ? @$value : ($value);
            for my $v (@values) {
                push @query_parts, _url_encode($key) . '=' . _url_encode($v);
            }
        }
    }

    my $query_string = join '&', @query_parts;

    # Extract options
    my $headers      = delete $opts{headers} // [];
    my $body         = delete $opts{body} // '';
    my $scheme       = delete $opts{scheme} // 'http';
    my $host         = delete $opts{host} // 'localhost';
    my $http_version = delete $opts{http_version} // '1.1';
    my $client       = delete $opts{client} // ['127.0.0.1', 0];
    my $server       = delete $opts{server} // ['127.0.0.1', 80];

    croak "Unknown options: " . join(', ', keys %opts) if %opts;

    # Ensure host header is present
    my $has_host = 0;
    for my $h (@$headers) {
        if (lc($h->[0]) eq 'host') {
            $has_host = 1;
            last;
        }
    }
    push @$headers, ['host', $host] unless $has_host;

    # Add content-length if body present and not already set
    if (length($body) > 0) {
        my $has_cl = 0;
        for my $h (@$headers) {
            if (lc($h->[0]) eq 'content-length') {
                $has_cl = 1;
                last;
            }
        }
        push @$headers, ['content-length', length($body)] unless $has_cl;
    }

    # Build scope
    my $scope = {
        type         => 'http',
        pagi         => {
            version      => '0.1',
            spec_version => '0.1',
        },
        http_version => $http_version,
        method       => uc($method),
        scheme       => $scheme,
        path         => $clean_path,
        raw_path     => $clean_path,  # In test mode, we don't percent-encode
        query_string => $query_string,
        headers      => $headers,
        client       => $client,
        server       => $server,
        extensions   => $self->{extensions},
        state        => $self->{state},
    };

    # Create receive queue
    my @receive_queue;

    # Queue body if present
    if (length($body) > 0) {
        push @receive_queue, {
            type => 'http.request',
            body => $body,
            more => 0,
        };
    }

    my $receive = sub {
        if (@receive_queue) {
            return Future->done(shift @receive_queue);
        }
        # No more data - return disconnect
        return Future->done({ type => 'http.disconnect' });
    };

    # Capture response
    my %response = (
        status  => undef,
        headers => [],
        body    => '',
        events  => [],  # Track all send events for debugging
    );

    my $send = async sub {
        my ($event) = @_;

        push @{$response{events}}, $event;

        my $type = $event->{type} // '';

        if ($type eq 'http.response.start') {
            $response{status} = $event->{status};
            $response{headers} = $event->{headers} // [];
        }
        elsif ($type eq 'http.response.body') {
            $response{body} .= $event->{body} // '';
        }

        return;
    };

    # Run the app
    eval {
        await $self->{app}->($scope, $receive, $send);
    };
    my $error = $@;

    # If app threw an exception, return 500 response
    if ($error) {
        return PAGI::Test::Response->new(
            status  => 500,
            headers => [['content-type', 'text/plain']],
            body    => "Internal Server Error: $error",
            events  => $response{events},
            error   => $error,
        );
    }

    # Return captured response
    return PAGI::Test::Response->new(
        status  => $response{status} // 500,
        headers => $response{headers},
        body    => $response{body},
        events  => $response{events},
    );
}

sub get     { shift->request(GET     => @_) }
sub post    { shift->request(POST    => @_) }
sub put     { shift->request(PUT     => @_) }
sub patch   { shift->request(PATCH   => @_) }
sub delete  { shift->request(DELETE  => @_) }
sub head    { shift->request(HEAD    => @_) }
sub options { shift->request(OPTIONS => @_) }

async sub request_json {
    my ($self, $method, $path, $data, %opts) = @_;

    require JSON::PP;

    my $json = JSON::PP::encode_json($data);

    my $headers = delete $opts{headers} // [];
    push @$headers, ['content-type', 'application/json'];

    return await $self->request(
        $method => $path,
        headers => $headers,
        body    => $json,
        %opts,
    );
}

sub post_json  { shift->request_json(POST  => @_) }
sub put_json   { shift->request_json(PUT   => @_) }
sub patch_json { shift->request_json(PATCH => @_) }

async sub request_form {
    my ($self, $method, $path, $data, %opts) = @_;

    my @parts;
    for my $key (sort keys %$data) {
        my $value = $data->{$key};
        my @values = ref $value eq 'ARRAY' ? @$value : ($value);
        for my $v (@values) {
            push @parts, _url_encode($key) . '=' . _url_encode($v);
        }
    }

    my $body = join '&', @parts;

    my $headers = delete $opts{headers} // [];
    push @$headers, ['content-type', 'application/x-www-form-urlencoded'];

    return await $self->request(
        $method => $path,
        headers => $headers,
        body    => $body,
        %opts,
    );
}

sub post_form { shift->request_form(POST => @_) }

async sub run_lifespan {
    my ($self) = @_;

    return if $self->{lifespan_started};
    $self->{lifespan_started} = 1;

    my $scope = {
        type => 'lifespan',
        pagi => {
            version      => '0.1',
            spec_version => '0.1',
        },
        state => $self->{state},
    };

    my @send_queue;
    my $receive_pending;
    my $startup_complete = $self->{loop}->new_future;

    my $receive = sub {
        if (@send_queue) {
            return Future->done(shift @send_queue);
        }
        $receive_pending = $self->{loop}->new_future;
        return $receive_pending;
    };

    my $send = async sub {
        my ($event) = @_;
        my $type = $event->{type} // '';

        if ($type eq 'lifespan.startup.complete') {
            $startup_complete->done({ success => 1 });
        }
        elsif ($type eq 'lifespan.startup.failed') {
            my $message = $event->{message} // '';
            $startup_complete->done({ success => 0, message => $message });
        }
    };

    # Queue startup event
    push @send_queue, { type => 'lifespan.startup' };
    if ($receive_pending && !$receive_pending->is_ready) {
        my $f = $receive_pending;
        $receive_pending = undef;
        $f->done(shift @send_queue);
    }

    # Run app in background
    my $app_future = (async sub {
        eval {
            await $self->{app}->($scope, $receive, $send);
        };
        # If app doesn't support lifespan, that's fine
        if (!$startup_complete->is_ready) {
            $startup_complete->done({ success => 1, lifespan_supported => 0 });
        }
    })->();

    # Wait for startup complete (with timeout)
    my $timeout_f = $self->{loop}->delay_future(after => 5);
    await Future->wait_any($startup_complete, $timeout_f);

    if ($timeout_f->is_ready && !$startup_complete->is_ready) {
        croak "Lifespan startup timed out after 5 seconds";
    }

    my $result = $startup_complete->get;

    if (!$result->{success}) {
        my $message = $result->{message} // 'Lifespan startup failed';
        croak "Lifespan startup failed: $message";
    }

    return;
}

# Internal: URL encode a string
sub _url_encode {
    my ($str) = @_;
    return '' unless defined $str;
    $str =~ s/([^A-Za-z0-9_~.+-])/sprintf("%%%02X", ord($1))/eg;
    return $str;
}

1;

=head1 NAME

PAGI::Test - Test PAGI applications without a web server

=head1 SYNOPSIS

    use Test2::V0;
    use PAGI::Test;
    use Future::AsyncAwait;

    # Define your PAGI app
    my $app = async sub {
        my ($scope, $receive, $send) = @_;

        die "Unsupported: $scope->{type}" if $scope->{type} ne 'http';

        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [['content-type', 'text/plain']],
        });

        await $send->({
            type => 'http.response.body',
            body => 'Hello from PAGI!',
            more => 0,
        });
    };

    # Create test instance
    my $test = PAGI::Test->new(app => $app);

    # Make test requests
    my $res = $test->request(GET => '/')->get;

    is($res->status, 200, 'Status is 200');
    is($res->header('content-type'), 'text/plain', 'Content-Type correct');
    is($res->body, 'Hello from PAGI!', 'Body matches');

=head1 DESCRIPTION

PAGI::Test allows you to test PAGI applications without spinning up a web
server. It invokes your application directly with a synthetic scope and
captures the response for inspection.

This is useful for:

=over 4

=item * Unit testing application logic

=item * Testing without network I/O overhead

=item * Fast test suite execution

=item * Testing edge cases and error conditions

=back

=head1 CONSTRUCTOR

=head2 new

    my $test = PAGI::Test->new(
        app        => \&app,           # Required: PAGI application coderef
        loop       => $loop,            # Optional: IO::Async::Loop instance
        extensions => \%extensions,     # Optional: PAGI extensions to advertise
        state      => \%state,          # Optional: Shared state for lifespan
    );

Creates a new test instance.

=over 4

=item * C<app> - Required. Your PAGI application coderef.

=item * C<loop> - Optional. IO::Async::Loop instance. Creates one if not provided.

=item * C<extensions> - Optional. Extensions to advertise in scope.

=item * C<state> - Optional. Shared state hashref for lifespan protocol.

=back

=head1 METHODS

=head2 request

    my $response_future = $test->request($method => $path, %options);
    my $response = $test->request($method => $path, %options)->get;

Make a test request. Returns a Future that resolves to a PAGI::Test::Response.

B<Arguments:>

=over 4

=item * C<$method> - HTTP method (GET, POST, PUT, DELETE, etc.)

=item * C<$path> - Request path (may include query string)

=back

B<Options:>

=over 4

=item * C<headers> - Arrayref of [name, value] pairs

=item * C<body> - Request body (string or bytes)

=item * C<query> - Hashref of query parameters (merged with path query string)

=item * C<scheme> - 'http' or 'https' (default: 'http')

=item * C<host> - Host header value (default: 'localhost')

=item * C<http_version> - HTTP version (default: '1.1')

=item * C<client> - Client address arrayref [host, port] (default: ['127.0.0.1', 0])

=item * C<server> - Server address arrayref [host, port] (default: ['127.0.0.1', 80])

=back

B<Example:>

    # Simple GET
    my $res = $test->request(GET => '/users')->get;

    # POST with JSON body
    my $res = $test->request(
        POST => '/users',
        headers => [['content-type', 'application/json']],
        body => '{"name":"John"}',
    )->get;

    # GET with query params
    my $res = $test->request(
        GET => '/search',
        query => { q => 'perl', limit => 10 },
    )->get;

=head2 get, post, put, patch, delete, head, options

    my $res = $test->get('/users')->get;
    my $res = $test->post('/users', body => '...')->get;
    my $res = $test->put('/users/1', body => '...')->get;
    my $res = $test->patch('/users/1', body => '...')->get;
    my $res = $test->delete('/users/1')->get;
    my $res = $test->head('/users')->get;
    my $res = $test->options('/users')->get;

Convenience methods for common HTTP methods.

=head2 request_json

    my $res = $test->request_json(POST => '/api/users', {
        name => 'John',
        age  => 30,
    })->get;

Convenience method for making JSON requests. Automatically sets Content-Type
and serializes the data structure to JSON.

=head2 post_json, put_json, patch_json

    my $res = $test->post_json('/api/users', { name => 'John' })->get;

Convenience methods for JSON requests.

=head2 request_form

    my $res = $test->request_form(POST => '/login', {
        username => 'john',
        password => 'secret',
    })->get;

Convenience method for making form-encoded requests.

=head2 post_form

    my $res = $test->post_form('/login', { username => 'john' })->get;

Convenience method for form POST requests.

=head2 run_lifespan

    $test->run_lifespan->get;

Manually run the lifespan startup sequence. This is optional - it's called
automatically on first request if not already run.

Returns a Future that resolves when lifespan startup completes.

=head1 EXAMPLES

=head2 Basic Testing

    use Test2::V0;
    use PAGI::Test;

    my $test = PAGI::Test->new(app => $app);

    subtest 'GET /users' => sub {
        my $res = $test->get('/users')->get;

        ok($res->is_success, 'Request successful');
        is($res->status, 200, 'Status is 200');
        is($res->header('content-type'), 'application/json', 'JSON response');

        my $data = $res->json;
        ok(@$data > 0, 'Got users');
    };

=head2 Testing JSON APIs

    my $test = PAGI::Test->new(app => $app);

    # Create user
    my $res = $test->post_json('/api/users', {
        name  => 'John Doe',
        email => 'john@example.com',
    })->get;

    ok($res->is_success, 'User created');
    my $user = $res->json;
    ok($user->{id}, 'User has ID');

    # Update user
    $res = $test->put_json("/api/users/$user->{id}", {
        name => 'Jane Doe',
    })->get;

    ok($res->is_success, 'User updated');

=head2 Testing Form Submissions

    my $test = PAGI::Test->new(app => $app);

    my $res = $test->post_form('/login', {
        username => 'john',
        password => 'secret',
    })->get;

    ok($res->is_redirect, 'Login redirects');
    is($res->status, 302, 'Redirects to dashboard');

=head2 Testing with Custom Headers

    my $res = $test->request(
        GET => '/api/protected',
        headers => [
            ['authorization', 'Bearer token123'],
            ['x-api-version', 'v2'],
        ],
    )->get;

    ok($res->is_success, 'Authenticated request');

=head2 Testing Error Conditions

    my $res = $test->get('/nonexistent')->get;

    is($res->status, 404, 'Not found');
    ok($res->is_error, 'Is error response');

=head1 COMPARISON WITH FULL SERVER

PAGI::Test invokes your application directly without HTTP parsing or network
I/O. This makes tests fast but means some edge cases aren't tested:

=over 4

=item * HTTP protocol parsing (invalid headers, chunked encoding, etc.)

=item * Network timeouts and disconnections

=item * TLS/SSL handling

=item * WebSocket and SSE connections

=back

For comprehensive integration testing, use PAGI::Server with a real HTTP
client. For fast unit testing of application logic, use PAGI::Test.

=head1 SEE ALSO

L<PAGI>, L<PAGI::Server>, L<PAGI::Request>

=head1 AUTHOR

PAGI::Test was created for the PAGI project.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

