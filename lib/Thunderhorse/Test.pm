package Thunderhorse::Test;

use v5.40;
use Mooish::Base -standard;

use Test2::V1;
use PAGI::Test::Client;

has param 'app' => (
	isa => InstanceOf ['Thunderhorse::App'],
);

has field 'test' => (
	isa => InstanceOf ['PAGI::Test::Client'],
	lazy => 1,
);

has field 'response' => (
	isa => InstanceOf ['PAGI::Test::Response'],
	writer => 1,
);

sub _build_test ($self)
{
	return PAGI::Test::Client->new(app => $self->app->run);
}

sub request ($self, $path, %args)
{
	my $method = lc(delete $args{method} // 'GET');
	$self->set_response($self->test->$method($path, %args));
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

