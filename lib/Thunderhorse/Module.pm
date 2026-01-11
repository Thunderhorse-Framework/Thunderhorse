package Thunderhorse::Module;

use v5.40;
use Mooish::Base -standard;

extends 'Gears::Component';

has extended 'app' => (
	handles => [
		qw(
			add_method
			add_middleware
			add_hook
		)
	],
);

has param 'config' => (
	isa => HashRef,
);

