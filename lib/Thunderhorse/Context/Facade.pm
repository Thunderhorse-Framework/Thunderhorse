package Thunderhorse::Context::Facade;

use v5.40;

use Mooish::Base -standard;

use Devel::StrictMode;

# use handles for fast access (autoloading is kind of slow)
has param 'context' => (
	(STRICT ? (isa => InstanceOf ['Thunderhorse::Context']) : ()),
	handles => [
		qw(
			app
			req
			res
		)
	],
);

with qw(Thunderhorse::Autoloadable);

sub _autoload_from { 'context' }

