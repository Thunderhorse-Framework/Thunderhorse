package Thunderhorse::Autoloadable;

use v5.40;
use Mooish::Base -standard, -role;

requires qw(_autoload_from);

# autoload the rest
sub AUTOLOAD ($self, @args)
{
	our $AUTOLOAD;

	# TODO: SUPER::can?
	state %methods;
	my $method = $methods{$AUTOLOAD} //= do {
		my $wanted = $AUTOLOAD =~ s{^.+::}{}r;
		my $bad_method = $wanted eq 'DESTROY';
		!$bad_method ? $wanted : undef;
	};

	return unless defined $method;

	state %autoloadable;
	my $source = $autoloadable{ref $self} //= do {
		my $is_object = length ref $self;
		$is_object ? $self->_autoload_from : undef;
	};

	# do not call _source in package context
	die "no such method $method"
		unless defined $source;

	return $self->{$source}->$method(@args);
}

sub can ($self, $method)
{
	state %autoloadable;
	my $source = $autoloadable{ref $self} //= do {
		my $is_object = length ref $self;
		$is_object ? $self->_autoload_from : undef;
	};

	if ($source) {
		my $source_can = $self->{$source}->can($method);
		return $source_can if $source_can;
	}

	return $self->SUPER::can($method);
}

