package Thunderhorse::Module::Template;

use v5.40;
use Mooish::Base -standard;

use Gears::X::Thunderhorse;
use Gears::Template::TT;

extends 'Thunderhorse::Module';

has field 'template' => (
	isa => InstanceOf ['Gears::Template'],
	writer => -hidden,
);

sub build ($self)
{
	my $config = $self->config;

	my $tpl = Gears::Template::TT->new($config->%*);
	$self->_set_template($tpl);

	$self->register(
		controller => render => sub ($controller, $template, $vars = {}) {
			return $tpl->process($template, $vars);
		}
	);
}

