use v5.40;
use Test2::V1 -ipP;
use Test2::Thunderhorse;
use Log::Log4perl;
use HTTP::Request::Common;

################################################################################
# This tests whether Thunderhorse Logger module works
################################################################################

package LoggerApp {
	use Mooish::Base -standard;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		# Configure Log4perl with TestBuffer appender to capture output
		$self->load_module(
			'Logger' => {
				conf => \<<~CONF,
				log4perl.rootLogger=DEBUG, test
				log4perl.appender.test=Log::Log4perl::Appender::TestBuffer
				log4perl.appender.test.layout=PatternLayout
				log4perl.appender.test.layout.ConversionPattern=%m%n
				CONF
			}
		);

		$self->router->add(
			'/test-log' => {
				to => 'test_log',
			}
		);

		$self->router->add(
			'/test-error' => {
				to => 'test_error',
			}
		);
	}

	sub test_log ($self, $ctx)
	{
		$self->log(info => 'Test message');
		return 'logged';
	}

	sub test_error ($self, $ctx)
	{
		die "Test error\n";
	}
};

my $app = LoggerApp->new;
my $appender = Log::Log4perl->appenders->{test};

subtest 'should have access to log method' => sub {
	$appender->buffer('');    # Clear buffer

	http $app, GET '/test-log';
	http_status_is 200;
	http_text_is 'logged';

	my $buffer = $appender->buffer();
	like($buffer, qr/^\[.+\] \[INFO\] Test message/, 'log message captured');
};

subtest 'should catch and log errors' => sub {
	$appender->buffer('');    # Clear buffer

	http $app, GET '/test-error';
	http_status_is 500;

	my $buffer = $appender->buffer();
	like($buffer, qr/^\[.+\] \[ERROR\] Test error/, 'error message captured');
};

done_testing;

