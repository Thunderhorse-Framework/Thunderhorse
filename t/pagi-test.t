#!/usr/bin/env perl
use strict;
use warnings;
use Test2::V0;
use Future::AsyncAwait;

use lib 'lib';
use PAGI::Test;

# Simple test app
my $app = async sub {
    my ($scope, $receive, $send) = @_;

    # Handle lifespan
    if ($scope->{type} eq 'lifespan') {
        while (1) {
            my $event = await $receive->();
            if ($event->{type} eq 'lifespan.startup') {
                await $send->({ type => 'lifespan.startup.complete' });
            }
            elsif ($event->{type} eq 'lifespan.shutdown') {
                await $send->({ type => 'lifespan.shutdown.complete' });
                last;
            }
        }
        return;
    }

    die "Unsupported: $scope->{type}" if $scope->{type} ne 'http';

    # Simple routing
    my $path = $scope->{path};
    my $method = $scope->{method};

    if ($method eq 'GET' && $path eq '/') {
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
    }
    elsif ($method eq 'GET' && $path eq '/json') {
        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [['content-type', 'application/json']],
        });
        await $send->({
            type => 'http.response.body',
            body => '{"message":"Hello JSON"}',
            more => 0,
        });
    }
    elsif ($method eq 'POST' && $path eq '/echo') {
        my $body = '';
        while (1) {
            my $msg = await $receive->();
            last unless $msg && $msg->{type};
            last if $msg->{type} eq 'http.disconnect';
            $body .= $msg->{body} // '';
            last unless $msg->{more};
        }

        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [['content-type', 'text/plain']],
        });
        await $send->({
            type => 'http.response.body',
            body => $body,
            more => 0,
        });
    }
    elsif ($method eq 'GET' && $path eq '/query') {
        my $qs = $scope->{query_string} // '';
        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [['content-type', 'text/plain']],
        });
        await $send->({
            type => 'http.response.body',
            body => "Query: $qs",
            more => 0,
        });
    }
    else {
        await $send->({
            type    => 'http.response.start',
            status  => 404,
            headers => [['content-type', 'text/plain']],
        });
        await $send->({
            type => 'http.response.body',
            body => 'Not Found',
            more => 0,
        });
    }
};

subtest 'Basic GET request' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->get('/')->get;

    ok($res->is_success, 'Request successful');
    is($res->status, 200, 'Status is 200');
    is($res->header('content-type'), 'text/plain', 'Content-Type correct');
    is($res->body, 'Hello from PAGI!', 'Body matches');
    ok(!$res->is_error, 'Not an error');
    ok(!$res->is_redirect, 'Not a redirect');
};

subtest 'JSON response' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->get('/json')->get;

    ok($res->is_success, 'Request successful');
    is($res->status, 200, 'Status is 200');
    is($res->header('content-type'), 'application/json', 'JSON content type');

    my $data = $res->json;
    is($data->{message}, 'Hello JSON', 'JSON parsed correctly');
};

subtest 'POST with body' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->post('/echo', body => 'test data')->get;

    ok($res->is_success, 'Request successful');
    is($res->body, 'test data', 'Body echoed correctly');
};

subtest 'Query string' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->get('/query?foo=bar&baz=qux')->get;

    ok($res->is_success, 'Request successful');
    is($res->body, 'Query: foo=bar&baz=qux', 'Query string passed');
};

subtest 'Query parameter hash' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->get('/query', query => { foo => 'bar', baz => 'qux' })->get;

    ok($res->is_success, 'Request successful');
    like($res->body, qr/foo=bar/, 'Query params encoded');
    like($res->body, qr/baz=qux/, 'Multiple params work');
};

subtest '404 response' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->get('/nonexistent')->get;

    ok(!$res->is_success, 'Request not successful');
    ok($res->is_error, 'Is error');
    is($res->status, 404, 'Status is 404');
    is($res->body, 'Not Found', 'Error message correct');
};

subtest 'Custom headers' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->request(
        GET => '/',
        headers => [
            ['x-custom-header', 'test-value'],
            ['accept', 'text/plain'],
        ],
    )->get;

    ok($res->is_success, 'Request successful with custom headers');
};

subtest 'Different HTTP methods' => sub {
    my $test = PAGI::Test->new(app => $app);

    my $res1 = $test->put('/')->get;
    ok($res1->is_error, 'PUT returns 404');

    my $res2 = $test->delete('/')->get;
    ok($res2->is_error, 'DELETE returns 404');

    my $res3 = $test->patch('/')->get;
    ok($res3->is_error, 'PATCH returns 404');
};

subtest 'JSON convenience methods' => sub {
    my $json_app = async sub {
        my ($scope, $receive, $send) = @_;

        if ($scope->{type} eq 'lifespan') {
            my $event = await $receive->();
            if ($event->{type} eq 'lifespan.startup') {
                await $send->({ type => 'lifespan.startup.complete' });
            }
            return;
        }

        my $body = '';
        while (1) {
            my $msg = await $receive->();
            last unless $msg && $msg->{type};
            last if $msg->{type} eq 'http.disconnect';
            $body .= $msg->{body} // '';
            last unless $msg->{more};
        }

        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [['content-type', 'application/json']],
        });
        await $send->({
            type => 'http.response.body',
            body => $body,
            more => 0,
        });
    };

    my $test = PAGI::Test->new(app => $json_app);
    my $res = $test->post_json('/api', { name => 'John', age => 30 })->get;

    ok($res->is_success, 'JSON request successful');
    my $data = $res->json;
    is($data->{name}, 'John', 'JSON data sent correctly');
    is($data->{age}, 30, 'JSON numbers preserved');
};

subtest 'Form convenience methods' => sub {
    my $form_app = async sub {
        my ($scope, $receive, $send) = @_;

        if ($scope->{type} eq 'lifespan') {
            my $event = await $receive->();
            if ($event->{type} eq 'lifespan.startup') {
                await $send->({ type => 'lifespan.startup.complete' });
            }
            return;
        }

        my $body = '';
        while (1) {
            my $msg = await $receive->();
            last unless $msg && $msg->{type};
            last if $msg->{type} eq 'http.disconnect';
            $body .= $msg->{body} // '';
            last unless $msg->{more};
        }

        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [['content-type', 'text/plain']],
        });
        await $send->({
            type => 'http.response.body',
            body => $body,
            more => 0,
        });
    };

    my $test = PAGI::Test->new(app => $form_app);
    my $res = $test->post_form('/login', { username => 'john', password => 'secret' })->get;

    ok($res->is_success, 'Form request successful');
    like($res->body, qr/username=john/, 'Form data encoded');
    like($res->body, qr/password=secret/, 'Multiple fields encoded');
};

subtest 'App exception handling' => sub {
    my $error_app = async sub {
        my ($scope, $receive, $send) = @_;

        if ($scope->{type} eq 'lifespan') {
            my $event = await $receive->();
            if ($event->{type} eq 'lifespan.startup') {
                await $send->({ type => 'lifespan.startup.complete' });
            }
            return;
        }

        die "Intentional error";
    };

    my $test = PAGI::Test->new(app => $error_app);
    my $res = $test->get('/')->get;

    is($res->status, 500, 'Exception returns 500');
    ok($res->is_error, 'Is error response');
    like($res->body, qr/Intentional error/, 'Error message in body');
    ok($res->error, 'Error captured');
};

subtest 'Response events captured' => sub {
    my $test = PAGI::Test->new(app => $app);
    my $res = $test->get('/')->get;

    my @events = $res->events;
    ok(@events > 0, 'Events captured');

    my ($start) = grep { $_->{type} eq 'http.response.start' } @events;
    ok($start, 'Start event captured');
    is($start->{status}, 200, 'Status in start event');

    my ($body) = grep { $_->{type} eq 'http.response.body' } @events;
    ok($body, 'Body event captured');
    is($body->{body}, 'Hello from PAGI!', 'Body in event');
};

subtest 'Multiple header values' => sub {
    my $multi_header_app = async sub {
        my ($scope, $receive, $send) = @_;

        if ($scope->{type} eq 'lifespan') {
            my $event = await $receive->();
            if ($event->{type} eq 'lifespan.startup') {
                await $send->({ type => 'lifespan.startup.complete' });
            }
            return;
        }

        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [
                ['set-cookie', 'a=1'],
                ['set-cookie', 'b=2'],
                ['content-type', 'text/plain'],
            ],
        });
        await $send->({
            type => 'http.response.body',
            body => 'OK',
            more => 0,
        });
    };

    my $test = PAGI::Test->new(app => $multi_header_app);
    my $res = $test->get('/')->get;

    my @cookies = $res->header_all('set-cookie');
    is(scalar(@cookies), 2, 'Multiple header values captured');
    is($cookies[0], 'a=1', 'First cookie correct');
    is($cookies[1], 'b=2', 'Second cookie correct');

    # header() returns last value
    is($res->header('set-cookie'), 'b=2', 'header() returns last value');
};

done_testing;

