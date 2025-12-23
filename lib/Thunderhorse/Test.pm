package Thunderhorse::Test;

use v5.40;
use Mooish::Base -standard;

use Test2::V1;
use PAGI::Test;

has param 'app' => (
	isa => InstanceOf ['Thunderhorse::App'],
);

has field 'test' => (
	isa => InstanceOf ['PAGI::Test'],
	lazy => 1,
);

has field 'response' => (
	isa => InstanceOf ['PAGI::Test::Response'],
	writer => 1,
);

sub _build_test ($self)
{
	return PAGI::Test->new(app => $self->app->run);
}

sub request ($self, $path, %args)
{
	my $res = $self->test->request(delete $args{method} // 'GET', $path, %args)->get;
	$self->set_response($res);
	return $self;
}

sub status_is ($self, $wanted, $name = 'status ok')
{
	T2->is($self->response->status, $wanted, $name);

	return $self;
}

sub header_is ($self, $header, $wanted, $name = "header $header ok")
{
	my $headers = $self->response->headers;
	my $found;

	foreach my $res_header ($headers->@*) {
		next unless $res_header->[0] eq lc $header;
		$found = $res_header;
		last;
	}

	if ($found) {
		T2->is($found->[1], $wanted, $name);
	}
	else {
		T2->fail("no header $header in the response headers");
	}

	return $self;
}

sub body_is ($self, $wanted, $name = 'body ok')
{
	T2->is($self->response->body, $wanted, $name);

	return $self;
}

sub body_like ($self, $wanted, $name = 'body ok')
{
	T2->like($self->response->body, $wanted, $name);

	return $self;
}

