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
	default => sub { Thunderhorse::Router->new },
);

# async sub drain_request ($self, $receive) {
#     while (1) {
#         my $event = await $receive->();
#         # Exit if not a request event (e.g., http.disconnect)
#         last if $event->{type} ne 'http.request';
#         # Exit if this is the final body chunk
#         last unless $event->{more};
#     }
# }

async sub pagi ($self, $scope, $receive, $send)
{
	my $scope_type = $scope->{type};
	die 'Unsupported scope type'
		unless $scope_type =~ m/^(http|sse|websocket)$/;

	my $context = Thunderhorse::Context->new(app => $self);
	$scope = {$scope->%*};
	$context->set_pagi([$scope, $receive, $send]);

	$scope->{thunderhorse} = {
		context => $context,
	};

	my $req = $context->req;
	my $router = $self->router;
	my @matches = $router->flatten($router->match($req->method, $req->path));

	my $res = $context->res;
	foreach my $match (@matches) {
		my $location = $router->find($match->location);

		await $location->pagify($match->matched)->($scope, $receive, $send);
		last if $res->rendered;
	}

	if (!$res->rendered) {
		await $res->code(404)->render(text => 'Not found');
	}
}

sub run ($self)
{
	return sub (@args) {
		return $self->pagi(@args);
	}
}

