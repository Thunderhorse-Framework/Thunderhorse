package Gears::Logger::Log4perl;

use v5.40;
use Mooish::Base -standard;

use Gears::X::Logger;
use Log::Log4perl;
use Log::Log4perl::Level;

extends 'Gears::Logger';

use constant LEVELS_MAPPING => {
	trace => $TRACE,
	debug => $DEBUG,
	info => $INFO,
	warn => $WARN,
	error => $ERROR,
	fatal => $FATAL,
};

has param 'conf' => (
	isa => HashRef | Str | ScalarRef [Str],
);

has param 'category' => (
	isa => Str,
	default => '',
);

has field 'log4perl' => (
	writer => -hidden,
);

sub BUILD ($self, $)
{
	Log::Log4perl->init($self->conf);

	my $category = $self->category;

	$self->_set_log4perl(Log::Log4perl->get_logger($category));
}

sub _log_message ($self, $level, $message)
{
	my $log4perl_level = LEVELS_MAPPING->{$level};

	Gears::X::Logger->raise("unknown log level $level")
		unless defined $log4perl_level;

	$self->log4perl->log($log4perl_level, $message);
}

