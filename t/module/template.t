use v5.40;
use Test2::V1 -ipP;
use Test2::Thunderhorse;
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

my $app = TemplateApp->new;

subtest 'should render template from file with wrapper' => sub {
	http $app, GET '/test';
	http_status_is 200;
	http_header_is 'Content-Type', 'text/html; charset=utf-8';
	like http->text, qr{^zażółć gęślą jaźń Hello World!\v+$}, 'body ok';
};

subtest 'should render inline template' => sub {
	http $app, GET '/test-inline';
	http_status_is 200;
	http_text_is 'Hello Inline!';
};

subtest 'should render DATA template' => sub {
	http $app, GET '/test-data';
	http_status_is 200;
	like http->text, qr{^Data contents\v+$}, 'body ok';

	# again - test handle rewinding
	http $app, GET '/test-data';
	like http->text, qr{^Data contents\v+$}, 'body ok';
};

done_testing;

__DATA__
Data contents

