use Test2::V1 -ipP;
use Thunderhorse::Test;

################################################################################
# This tests whether Thunderhorse basic app works
################################################################################

package BasicApp {
	use v5.40;
	use Mooish::Base -standard;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		$self->router->add(
			'/basic/:ph' => {
				to => sub ($self, $context, $ph) {
					my $self_class = ref $self;
					my $context_class = ref $context;

					return "$self_class;$context_class;$ph";
				}
			}
		);
	}
};

my $t = Thunderhorse::Test->new(app => BasicApp->new);

subtest 'should route to a valid location' => sub {
	$t->request('/basic/placeholder')
		->status_is(200)
		->header_is('Content-Type', 'text/html')
		->body_is('BasicApp;Thunderhorse::Context;placeholder')
		;
};

subtest 'should route to 404' => sub {
	$t->request('/basic/')
		->status_is(404)
		->header_is('Content-Type', 'text/plain')
		->body_is('Not Found')
		;
};

done_testing;

