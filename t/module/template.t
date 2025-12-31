use v5.40;
use Test2::V1 -ipP;
use Thunderhorse::Test;
use HTTP::Request::Common;

################################################################################
# This tests whether Thunderhorse::Module::Template works
################################################################################

package TemplateApp {
	use Mooish::Base -standard;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		$self->load_module(
			'Template' => {
				paths => ['t/templates'],
				conf => {
					OUTLINE_TAG => qr{\V*%%},
				},
			}
		);

		$self->router->add(
			'/test' => {
				to => 'test',
			}
		);

		$self->router->add(
			'/test-inline' => {
				to => 'test_inline',
			}
		);

		$self->router->add(
			'/test-data' => {
				to => 'test_data',
			}
		);
	}

	sub test ($self, $ctx)
	{
		return $self->render('test.tt', {name => 'World'});
	}

	sub test_inline ($self, $ctx)
	{
		return $self->render(\'Hello [% name %]!', {name => 'Inline'});
	}

	sub test_data ($self, $ctx)
	{
		return $self->render(\*main::DATA);
	}
}

my $t = Thunderhorse::Test->new(app => TemplateApp->new);

subtest 'should render template from file with wrapper' => sub {
	$t->request(GET '/test')
		->status_is(200)
		->header_is('Content-Type', 'text/html; charset=utf-8')
		->body_like(qr{^zażółć gęślą jaźń Hello World!\v+$})
		;
};

subtest 'should render inline template' => sub {
	$t->request(GET '/test-inline')
		->status_is(200)
		->body_is('Hello Inline!')
		;
};

subtest 'should render DATA template' => sub {
	$t->request(GET '/test-data')
		->status_is(200)
		->body_like(qr{^Data contents\v+$})
		;

	# again - test handle rewinding
	$t->request(GET '/test-data')
		->body_like(qr{^Data contents\v+$})
		;
};

done_testing;

__DATA__
Data contents

