package Thunderhorse::App;

use v5.40;
use Mooish::Base -standard;

use Thunderhorse::Context;
use Thunderhorse::Router;

use IO::Async::Loop;
use Future::AsyncAwait;

extends 'Gears::App';

has field 'loop' => (
	isa => InstanceOf ['IO::Async::Loop'],
	default => sub { IO::Async::Loop->new },
);

has extended 'router' => (
	isa => InstanceOf ['Thunderhorse::Router'],
	default => sub { Thunderhorse::Router->new },
);

with 'Thunderhorse::Routable';

async sub pagi ($self, $scope, $receive, $send)
{
	my $scope_type = $scope->{type};
	die 'Unsupported scope type'
		unless $scope_type =~ m/^(http|sse|websocket)$/;

	$scope = {$scope->%*};
	my $ctx = Thunderhorse::Context->new(
		app => $self,
		pagi => [$scope, $receive, $send],
	);

	$scope->{thunderhorse} = $ctx;

	my $req = $ctx->req;
	my $router = $self->router;
	my $matches = $router->match($req->path, $req->method);

	await $self->pagi_loop($ctx, $matches->@*);

	if (!$ctx->is_consumed) {
		await $ctx->res->status(404)->text('Not Found');
	}

	return;
}

sub run ($self)
{
	return sub (@args) {
		return $self->pagi(@args);
	}
}

