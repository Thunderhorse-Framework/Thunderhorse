use v5.40;
use Test2::V1 -ipP;
use Thunderhorse::Test;

################################################################################
# This tests whether Thunderhorse basic app works
################################################################################

package BasicApp {
	use Mooish::Base -standard;

	use Gears::X::HTTP;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		my $router = $self->router;

		$router->add(
			'/foundation/:ph' => {
				to => sub ($self, $ctx, $ph) {
					my $self_class = ref $self;
					my $ctx_class = ref $ctx;

					return "$self_class;$ctx_class;$ph";
				}
			}
		);

		$router->add(
			'/send' => {
				to => sub ($self, $ctx) {
					$ctx->res->text('this gets rendered');
					return 'this does not get rendered';
				}
			}
		);

		my $bridge = $router->add(
			'/bridge/:must_be_zero' => {
				to => sub ($self, $ctx, $must_be_zero) {
					Gears::X::HTTP->raise(403 => 'this exception renders 403, but this message is private')
						unless $must_be_zero eq '0';

					return undef;
				}
			}
		);

		$bridge->add(
			'/success' => {
				to => sub ($self, $ctx, $) {
					return 'bridge passed';
				},
			}
		);

		my $bridge_unimplemented = $router->add('/bridge2');

		$bridge_unimplemented->add(
			'/success' => {
				to => sub ($self, $ctx) {
					return 'bridge passed';
				},
			},
		);
	}
};

my $t = Thunderhorse::Test->new(app => BasicApp->new);

subtest 'should route to a valid location' => sub {
	$t->request('/foundation/placeholder')
		->status_is(200)
		->header_is('Content-Type', 'text/html; charset=utf-8')
		->body_is('Thunderhorse::AppController;Thunderhorse::Context::Facade;placeholder')
		;
};

subtest 'should route to 404' => sub {
	$t->request('/foundation/')
		->status_is(404)
		->header_is('Content-Type', 'text/plain; charset=utf-8')
		->body_is('Not Found')
		;
};

subtest 'should render text set by res->text' => sub {
	$t->request('/send')
		->status_is(200)
		->header_is('Content-Type', 'text/plain; charset=utf-8')
		->body_is('this gets rendered')
		;
};

subtest 'should pass bridge and reach success route' => sub {
	$t->request('/bridge/0/success')
		->status_is(200)
		->header_is('Content-Type', 'text/html; charset=utf-8')
		->body_is('bridge passed')
		;
};

subtest 'should fail bridge and return 403' => sub {
	$t->request('/bridge/1/success')
		->status_is(403)
		->header_is('Content-Type', 'text/plain; charset=utf-8')
		# TODO: ->body_is('Forbidden')
		->body_is('Error')
		;
};

subtest 'should pass unimplemented bridge' => sub {
	$t->request('/bridge2/success')
		->status_is(200)
		->header_is('Content-Type', 'text/html; charset=utf-8')
		->body_is('bridge passed')
		;
};

done_testing;

