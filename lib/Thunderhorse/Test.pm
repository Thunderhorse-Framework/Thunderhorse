package Thunderhorse::Test;

use v5.40;
use Mooish::Base -standard;

use Test2::V1;
use PAGI::Test::Client;
use HTTP::Request::Common;

die 'Error: Thunderhorse::Test loaded in a PAGI environment'
	if $ENV{PAGI_ENV};
$ENV{PAGI_ENV} = 'test';

has param 'app' => (
	isa => InstanceOf ['Thunderhorse::App'],
);

has param 'raise_exceptions' => (
	isa => Bool,
	writer => 1,
	default => true,
);

has field 'test' => (
	isa => InstanceOf ['PAGI::Test::Client'],
	lazy => 1,
);

has field 'response' => (
	isa => InstanceOf ['PAGI::Test::Response'],
	writer => 1,
);

has field 'websocket' => (
	isa => InstanceOf ['PAGI::Test::WebSocket'],
	writer => 1,
);

has field 'sse' => (
	isa => InstanceOf ['PAGI::Test::SSE'],
	writer => 1,
);

sub _build_test ($self)
{
	return PAGI::Test::Client->new(app => $self->app->run);
}

sub request ($self, $http_request)
{
	my %args;

	# Extract method and path
	my $method = lc $http_request->method;
	my $path = $http_request->uri->path_query;

	# Extract headers
	my %headers;
	$http_request->headers->scan(
		sub ($key, $value) {
			push $headers{$key}->@*, $value;
		}
	);

	$args{headers} = \%headers
		if %headers;

	# Extract body for POST/PUT/PATCH
	my $content = $http_request->content;
	$args{body} = $content
		if length $content // '';

	$self->set_response($self->test->$method($path, %args));

	if ($self->response->exception && $self->raise_exceptions) {
		die $self->response->exception;
	}

	return $self;
}

sub status_is ($self, $wanted, $name = 'status ok')
{
	T2->is($self->response->status, $wanted, $name);

	return $self;
}

sub header_is ($self, $header, $wanted, $name = "header $header ok")
{
	my $got_header = $self->response->header($header);
	T2->is($got_header, $wanted, $name);

	return $self;
}

sub body_is ($self, $wanted, $name = 'body ok')
{
	T2->is($self->response->text, $wanted, $name);

	return $self;
}

sub body_like ($self, $wanted, $name = 'body ok')
{
	T2->like($self->response->text, $wanted, $name);

	return $self;
}

sub exception_like ($self, $wanted, $name = 'exception ok')
{
	T2->like($self->response->exception, $wanted, $name);

	return $self;
}

## WEBSOCKET TESTING

sub websocket_connect ($self, $path, %args)
{
	my $ws = $self->test->websocket($path, %args);
	$self->set_websocket($ws);
	return $self;
}

sub websocket_close ($self)
{
	$self->websocket->close unless $self->websocket->is_closed;
	return $self;
}

sub ws_send_text ($self, $text)
{
	$self->websocket->send_text($text);
	return $self;
}

sub ws_send_bytes ($self, $bytes)
{
	$self->websocket->send_bytes($bytes);
	return $self;
}

sub ws_send_json ($self, $data)
{
	$self->websocket->send_json($data);
	return $self;
}

sub ws_receive_text ($self)
{
	return $self->websocket->receive_text;
}

sub ws_receive_bytes ($self)
{
	return $self->websocket->receive_bytes;
}

sub ws_receive_json ($self)
{
	return $self->websocket->receive_json;
}

sub ws_text_is ($self, $wanted, $name = 'ws text ok')
{
	my $got = $self->ws_receive_text;
	T2->is($got, $wanted, $name);
	return $self;
}

sub ws_json_is ($self, $wanted, $name = 'ws json ok')
{
	my $got = $self->ws_receive_json;
	T2->is($got, $wanted, $name);
	return $self;
}

sub ws_closed_ok ($self, $name = 'ws closed ok')
{
	T2->ok($self->websocket->is_closed, $name);
	return $self;
}

sub ws_connected_ok ($self, $name = 'ws connected ok')
{
	T2->ok(!$self->websocket->is_closed, $name);
	return $self;
}

## SSE TESTING

sub sse_connect ($self, $path, %args)
{
	my $sse = $self->test->sse($path, %args);
	$self->set_sse($sse);
	return $self;
}

sub sse_close ($self)
{
	$self->sse->close unless $self->sse->is_closed;
	return $self;
}

sub sse_receive_event ($self, %args)
{
	return $self->sse->receive_event(%args);
}

sub sse_receive_json ($self, %args)
{
	return $self->sse->receive_json(%args);
}

sub sse_event_is ($self, $wanted, $name = 'sse event ok')
{
	my $got = $self->sse_receive_event;
	T2->is($got, $wanted, $name);
	return $self;
}

sub sse_data_is ($self, $wanted, $name = 'sse data ok')
{
	my $got = $self->sse_receive_event;
	T2->is($got->{data}, $wanted, $name);
	return $self;
}

sub sse_json_is ($self, $wanted, $name = 'sse json ok')
{
	my $got = $self->sse_receive_json;
	T2->is($got, $wanted, $name);
	return $self;
}

sub sse_closed_ok ($self, $name = 'sse closed ok')
{
	T2->ok($self->sse->is_closed, $name);
	return $self;
}

