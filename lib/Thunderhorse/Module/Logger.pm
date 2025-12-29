package Thunderhorse::Module::Logger;

use v5.40;
use Mooish::Base -standard;

use Gears::X::Thunderhorse;
use Gears::Logger::Log4perl;

use Future::AsyncAwait;

extends 'Thunderhorse::Module';

has field 'logger' => (
	isa => InstanceOf ['Gears::Logger'],
	writer => -hidden,
);

sub build ($self)
{
	weaken $self;
	my $config = $self->config;

	my $logger = Gears::Logger::Log4perl->new($config->%*);
	$self->_set_logger($logger);

	$self->register(
		controller => log => sub ($controller, $level, @messages) {
			$logger->message($level, @messages);
			return $controller;
		}
	);

	$self->wrap(
		sub ($app) {
			return async sub (@args) {
				try {
					await $app->(@args);
				}
				catch ($ex) {
					$logger->message(error => "$ex");
					die $ex;
				}
			};
		}
	);
}

