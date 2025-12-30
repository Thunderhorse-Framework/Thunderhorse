use v5.40;
use Test2::V1 -ipP;
use Thunderhorse::Test;
use Log::Log4perl;

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

my $t = Thunderhorse::Test->new(app => LoggerApp->new, raise_exceptions => false);
my $appender = Log::Log4perl->appenders->{test};

subtest 'should have access to log method' => sub {
	$appender->buffer('');    # Clear buffer

	$t->request('/test-log')
		->status_is(200)
		->body_is('logged')
		;

	my $buffer = $appender->buffer();
	like($buffer, qr/^\[.+\] \[INFO\] Test message/, 'log message captured');
};

subtest 'should catch and log errors' => sub {
	$appender->buffer('');    # Clear buffer

	$t->request('/test-error')
		->status_is(500)
		;

	my $buffer = $appender->buffer();
	like($buffer, qr/^\[.+\] \[ERROR\] Test error/, 'error message captured');
};

done_testing;

