use Test2::V1 -ipP;
use Thunderhorse::Test;

################################################################################
# This tests whether Thunderhorse can seamlessly integrate PAGI apps
################################################################################

package PagiApp {
	use v5.40;
	use Mooish::Base -standard;

	use Future::AsyncAwait;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		my $router = $self->router;

		# use pagi => true to integrate a PAGI app
		$router->add(
			'/pagi_app' => {
				to => async sub ($scope, $receive, $send) {
					await $send->(
						{
							type => 'http.response.start',
							status => 200,
							headers => [['content-type', 'text/plain']],
						}
					);

					await $send->(
						{
							type => 'http.response.body',
							body => 'Hello from PAGI',
						}
					);
				},
				pagi => true,
			}
		);

		# this should not run, because first app should consume the context
		$router->add(
			'/pagi_app' => {
				to => sub ($self, $ctx) {
					die 'inaccessible';
				}
			}
		);
	}
};

my $t = Thunderhorse::Test->new(app => PagiApp->new);

subtest 'should route to a valid PAGI location' => sub {
	$t->request('/pagi_app')
		->status_is(200)
		->header_is('Content-Type', 'text/plain')
		->body_is('Hello from PAGI')
		;
};

done_testing;

