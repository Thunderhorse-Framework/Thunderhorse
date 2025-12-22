package HelloApp;

use v5.40;
use Mooish::Base -standard;

extends 'Thunderhorse::App';

sub build ($self)
{
	$self->set_controllers('Hello');
}

