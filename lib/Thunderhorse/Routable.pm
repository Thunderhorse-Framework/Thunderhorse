package Thunderhorse::Routable;

use v5.40;
use Mooish::Base -standard, -role;

use Future::AsyncAwait;
use Thunderhorse::Context::Facade;

requires qw(
	app
);

sub make_facade ($self, $ctx)
{
	return Thunderhorse::Context::Facade->new(context => $ctx);
}

around router => sub ($orig, $self) {
	my $router = $self->$orig;
	$router->set_controller($self);
	return $router;
};

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

