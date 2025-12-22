package HelloApp;

use v5.40;
use Mooish::Base -standard;

extends 'Thunderhorse::App';

sub build ($self)
{
	my $r = $self->router;

	$r->add(
		'/hello/?msg' => {
			to => sub ($self, $context, $msg) {
				return "Hello, $msg";
			},
			defaults => {
				msg => 'world',
			},
		}
	);
}

