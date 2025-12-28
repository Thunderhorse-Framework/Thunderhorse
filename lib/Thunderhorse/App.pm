package Thunderhorse::App;

use v5.40;
use Mooish::Base -standard;

use Thunderhorse::Context;
use Thunderhorse::Router;
use Thunderhorse::Controller;
use Thunderhorse::AppController;

use IO::Async::Loop;
use Future::AsyncAwait;

extends 'Gears::App';

has field 'loop' => (
	isa => InstanceOf ['IO::Async::Loop'],
	default => sub { IO::Async::Loop->new },
);

has field 'app_controller' => (
	isa => InstanceOf ['Thunderhorse::Controller'],
	lazy => 1,
);

has extended 'router' => (
	reader => '_router',
	isa => InstanceOf ['Thunderhorse::Router'],
	default => sub { Thunderhorse::Router->new },
);

sub _build_app_controller ($self)
{
	return Thunderhorse::AppController->new(app => $self);
}

sub router ($self)
{
	my $router = $self->_router;
	$router->set_controller($self->app_controller);
	return $router;
}

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
	my $router = $self->_router;
	my $matches = $router->match($req->path, $req->method);

	await $self->pagi_loop($ctx, $matches->@*);

	if (!$ctx->is_consumed) {
		await $ctx->res->status(404)->text('Not Found');
	}

	return;
}

async sub pagi_loop ($self, $ctx, @matches)
{
	my @pagi = $ctx->pagi->@*;

	foreach my $match (@matches) {
		# is this a bridge? If yes, take first element (the bridge location).
		# It is guaranteed to be a match, not an array
		my $loc = (ref $match eq 'ARRAY' ? $match->[0] : $match)->location;

		# $ctx->match may be an array if this is a bridge. Location handler
		# takes care of that
		$ctx->set_match($match);

		# execute location handler (PAGI application)
		await $loc->pagi_app->(@pagi);
		last if $ctx->is_consumed;
	}
}

sub run ($self)
{
	return sub (@args) {
		return $self->pagi(@args);
	}
}

