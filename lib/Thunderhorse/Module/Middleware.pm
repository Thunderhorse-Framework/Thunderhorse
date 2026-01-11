package Thunderhorse::Module::Middleware;

use v5.40;
use Mooish::Base -standard;

use Gears::X::Thunderhorse;
use Gears qw(load_component get_component_name);

extends 'Thunderhorse::Module';

sub build ($self)
{
	weaken $self;
	my %wrap = $self->config->%*;

	# NOTE: order must be reversed, because of LIFO
	my @keys = reverse sort { ($wrap{$a}{_order} // 0) <=> ($wrap{$b}{_order} // 0) or $a cmp $b }
		keys %wrap;

	foreach my $key (@keys) {
		delete $wrap{$key}{_order};

		my $class = load_component(get_component_name($key, 'PAGI::Middleware'));
		my $mw = $class->new($wrap{$key}->%*);
		$self->add_middleware($mw);
	}
}

