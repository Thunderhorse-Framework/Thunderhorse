use v5.40;
use Test2::V1 -ipP;
use Test2::Thunderhorse;
use HTTP::Request::Common;

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

my $app = BasicApp->new;

subtest 'should route to a valid location' => sub {
	http $app, GET '/foundation/placeholder';
	http_status_is 200;
	http_header_is 'content-type', 'text/html; charset=utf-8';
	http_text_is 'Thunderhorse::AppController;Thunderhorse::Context::Facade;placeholder';
};

subtest 'should route to 404' => sub {
	http $app, GET '/foundation';
	http_status_is 404;
	http_header_is 'Content-Type', 'text/plain; charset=utf-8';
	http_text_is 'Not Found';
};

subtest 'should render text set by res->text' => sub {
	http $app, GET '/send';
	http_status_is 200;
	http_header_is 'Content-Type', 'text/plain; charset=utf-8';
	http_text_is 'this gets rendered';
};

subtest 'should pass bridge and reach success route' => sub {
	http $app, GET '/bridge/0/success';
	http_status_is 200;
	http_header_is 'Content-Type', 'text/html; charset=utf-8';
	http_text_is 'bridge passed';
};

subtest 'should fail bridge and return 403' => sub {
	http $app, GET '/bridge/1/success';
	http_status_is 403;
	http_header_is 'Content-Type', 'text/plain; charset=utf-8';
	# TODO: http_text_is('Forbidden')
	http_text_is 'Error';
};

subtest 'should pass unimplemented bridge' => sub {
	http $app, GET '/bridge2/success';
	http_status_is 200;
	http_header_is 'Content-Type', 'text/html; charset=utf-8';
	http_text_is 'bridge passed';
};

done_testing;

