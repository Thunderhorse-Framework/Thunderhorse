use Test2::V1 -ipP;
use Thunderhorse::Test;
use HTTP::Request::Common;

use Future::AsyncAwait;

################################################################################
# This tests whether Thunderhorse correctly handles various parameters
################################################################################

package ParamsApp {
	use v5.40;
	use Mooish::Base -standard;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		my $router = $self->router;

		$router->add(
			'/get' => {
				to => sub ($self, $ctx) {
					my $get = $ctx->req->query_params;
					my @response;
					foreach my $key (sort keys $get->%*) {
						push @response, "${key}: " . join ', ', $get->get_all($key);
					}

					return join "\n", @response;
				}
			}
		);

		$router->add(
			'/post' => {
				to => async sub ($self, $ctx) {
					my $form = await $ctx->req->form;
					my @response;
					foreach my $key (sort keys $form->%*) {
						push @response, "${key}: " . join ', ', $form->get_all($key);
					}

					return join "\n", @response;
				}
			}
		);

		$router->add(
			'/headers' => {
				to => sub ($self, $ctx) {
					my $headers = $ctx->req->headers;
					my @response;
					foreach my $key (sort keys $headers->%*) {
						push @response, "${key}: " . join ', ', $headers->get_all($key);
					}

					return join "\n", @response;
				}
			}
		);

	}
};

my $t = Thunderhorse::Test->new(app => ParamsApp->new);

subtest 'should handle single query parameter' => sub {
	$t->request(GET '/get?foo=bar')
		->status_is(200)
		->body_like(qr/^foo: bar$/m)
		;
};

subtest 'should handle multiple query parameters' => sub {
	$t->request(GET '/get?foo=bar&baz=qux')
		->status_is(200)
		->body_like(qr/^foo: bar$/m)
		->body_like(qr/^baz: qux$/m)
		;
};

subtest 'should handle query parameter with multiple values' => sub {
	$t->request(GET '/get?foo=bar&foo=baz')
		->status_is(200)
		->body_like(qr/^foo: bar, baz$/m)
		;
};

subtest 'should handle single form parameter' => sub {
	$t->request(POST '/post', [foo => 'bar'])
		->status_is(200)
		->body_like(qr/^foo: bar$/m)
		;
};

subtest 'should handle multiple form parameters' => sub {
	$t->request(POST '/post', [foo => 'bar', baz => 'qux'])
		->status_is(200)
		->body_like(qr/^foo: bar$/m)
		->body_like(qr/^baz: qux$/m)
		;
};

subtest 'should handle form parameter with multiple values' => sub {
	$t->request(POST '/post', [foo => 'bar', foo => 'baz'])
		->status_is(200)
		->body_like(qr/^foo: bar, baz$/m)
		;
};

subtest 'should handle custom headers' => sub {
	$t->request(GET '/headers', 'x-custom-header' => 'test-value')
		->status_is(200)
		->body_like(qr/^x-custom-header: test-value$/m)
		;
};

subtest 'should handle multiple header values' => sub {
	$t->request(GET '/headers', 'x-multi' => 'value1', 'x-multi' => 'value2')
		->status_is(200)
		->body_like(qr/^x-multi: value1, value2$/m)
		;
};

subtest 'should handle headers together with form' => sub {
	$t->request(POST '/headers', [foo => 'bar'], 'x-multi' => 'value')
		->status_is(200)
		->body_like(qr/^x-multi: value$/m)
		;

	$t->request(POST '/post', [foo => 'bar'], 'x-multi' => 'value')
		->status_is(200)
		->body_like(qr/^foo: bar$/m)
		;
};

done_testing;
