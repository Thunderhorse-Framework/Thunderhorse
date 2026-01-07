package Thunderhorse;

##################################
# ~~~~~~~~~~~~ Ride ~~~~~~~~~~~~ #
# ~~~~~~~~~~~~ Ride ~~~~~~~~~~~~ #
# ~~~~~~~~~~~~ Ride ~~~~~~~~~~~~ #
# ~~~~~~~~~~~~ Ride ~~~~~~~~~~~~ #
# ~~~~~~~~ Thunderhorse ~~~~~~~~ #
# ~~~~~~~~ Thunderhorse ~~~~~~~~ #
# ~~~~~~~~ Thunderhorse ~~~~~~~~ #
# ~~~~~~~~ Thunderhorse ~~~~~~~~ #
# ~~~~~~~~~~~ Revenge ~~~~~~~~~~ #
# ~~~~~~~~~~~ Revenge ~~~~~~~~~~ #
# ~~~~~~~~~~~ Revenge ~~~~~~~~~~ #
##################################

use v5.40;

use Exporter qw(import);
use Future::AsyncAwait;

use Gears::X::Thunderhorse;

our @EXPORT_OK = qw(
	pagi_loop
	adapt_pagi
	build_handler
);

async sub pagi_loop ($ctx, @matches)
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

sub adapt_pagi ($destination)
{
	# no need to async here because we don't await - destination must return a promise anyway
	# TODO: think of a proper way to enforce last placeholder being at the very end of the url
	return sub ($scope, @args) {
		Gears::X::Thunderhorse->raise('bad PAGI execution chain, not a Thunderhorse app')
			unless my $ctx = $scope->{thunderhorse};

		# consume this context eagerly to keep further matches from firing
		$ctx->consume;

		# take last matched element as the path
		# pagi apps can't be bridges, so don't check if $ctx->match is an array
		my $path = $ctx->match->matched->[-1] // '';
		my $trailing_slash = $scope->{path} =~ m{/$} ? '/' : '';
		$path =~ s{^/?}{/};
		$path =~ s{/?$}{$trailing_slash};

		# modify the scope for the app
		$scope = {$scope->%*};
		$scope->{root_path} = ($scope->{root_path} . $scope->{path}) =~ s{\Q$path\E$}{}r;
		$scope->{path} = $path;

		return $destination->($scope, @args);
	}
}

sub build_handler ($controller, $destination)
{
	return async sub ($scope, $receive, $send) {
		Gears::X::Thunderhorse->raise('bad PAGI execution chain, not a Thunderhorse app')
			unless my $ctx = $scope->{thunderhorse};

		$ctx->set_pagi([$scope, $receive, $send]);

		my $match = $ctx->match;
		my $bridge = ref $match eq 'ARRAY';

		# this location may be unimplemented when destination is undefined, but
		# a full handler should be built anyway. Unimplemented destinations
		# should still be wrappable in middleware.
		if (defined $destination) {
			try {
				my $facade = $controller->make_facade($ctx);
				my $result = $destination->($controller, $facade, ($bridge ? $match->[0] : $match)->matched->@*);
				$result = await $result
					if $result isa 'Future';

				if (!$ctx->is_consumed) {
					if (defined $result) {
						await $ctx->res->status_try(200)->content_type_try('text/html')->send($result);
					}
					else {
						weaken $facade;
						Gears::X::Thunderhorse->raise("context hasn't been given up - forgot await?")
							if defined $facade;
					}
				}
			}
			catch ($ex) {
				await $controller->_on_error($ctx, $ex);
			}
		}

		# if this is a bridge and bridge did not render, it means we are
		# free to go deeper. Avoid first match, as it was handled already
		# above
		if ($bridge && !$ctx->is_consumed) {
			await pagi_loop($ctx, $match->@[1 .. $match->$#*]);
		}
	};
}

1;

__END__

=head1 NAME

Thunderhorse - A no-compromises brutally-good web framework

=head1 SYNOPSIS

	use Thunderhorse;

	# do something

=head1 DESCRIPTION

Thunderhorse is a PAGI-native web framework. See L<Thunderhorse::Manual> for a
reference.

This is a stub release which will be fully documented later. Stay tuned.

=head1 SEE ALSO

L<Gears>

=head1 AUTHOR

Bartosz Jarzyna E<lt>bbrtj.pro@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 by Bartosz Jarzyna

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

