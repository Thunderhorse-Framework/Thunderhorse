package Thunderhorse::Response;

use v5.40;
use Mooish::Base -standard;

use Gears::X::Thunderhorse;
use Future::AsyncAwait;

extends 'PAGI::Response';
with 'Thunderhorse::Message';

sub FOREIGNBUILDARGS ($class, %args)
{
	Gears::X::Thunderhorse->raise('no context for response')
		unless $args{context};

	# PAGI::Response->new() now takes only the scope.
	return $args{context}->pagi->[0];
}

sub BUILD ($self, $args)
{
	# new() above ignores the sender (the old constructor stored it), so capture
	# it from the context here. update() refreshes it when the PAGI tuple changes
	# (e.g. next-match dispatch).
	$self->{send} = $self->context->pagi->[2];
}

sub update ($self, $scope, $receive, $send)
{
	$self->{scope} = $scope;
	$self->{send} = $send;
}

# PAGI::Response is a value: the terminal builders (text/html/json/redirect/
# send) set the body and return $self, while respond($send) performs the single
# send. Thunderhorse awaits a terminal builder to send the response, so bridge
# the two models here: build via the parent value method, then perform the
# guarded send. We set the shared pagi.response.sent scope flag exactly as
# PAGI::Context::HTTP->respond does, so the context's is_sent / is_consumed see
# the response as sent (and a double send is rejected).
async sub text ($self, @args)
{
	$self->SUPER::text(@args);
	return await $self->_send_response;
}

async sub html ($self, @args)
{
	$self->SUPER::html(@args);
	return await $self->_send_response;
}

async sub json ($self, @args)
{
	$self->SUPER::json(@args);
	return await $self->_send_response;
}

async sub redirect ($self, @args)
{
	$self->SUPER::redirect(@args);
	return await $self->_send_response;
}

async sub send ($self, @args)
{
	$self->SUPER::send(@args);
	return await $self->_send_response;
}

async sub _send_response ($self)
{
	my $scope = $self->{scope};
	Gears::X::Thunderhorse->raise('response already sent')
		if $scope && $scope->{'pagi.response.sent'};
	$scope->{'pagi.response.sent'} = 1 if $scope;
	return await $self->respond($self->{send});
}

__END__

=head1 NAME

Thunderhorse::Response - Response wrapper for Thunderhorse

=head1 SYNOPSIS

	async sub show ($self, $ctx, $id)
	{
		await $ctx->res->text("Hello World");
		await $ctx->res->json({data => 'value'});
		await $ctx->res->redirect('/login');
	}

=head1 DESCRIPTION

Thunderhorse::Response is a thin wrapper around L<PAGI::Response> that
integrates with L<Thunderhorse::Context>. It provides a fluent interface for
building and sending HTTP responses, including JSON, HTML, redirects, and file
downloads.

This class extends L<PAGI::Response> and mixes in C<Thunderhorse::Message> to
provide context integration.

=head1 INTERFACE

Inherits all interface from L<PAGI::Response>, and adds the interface
documented below.

=head2 Attributes

=head3 context

The L<Thunderhorse::Context> object for this request (weakened).

I<Required in the constructor>

=head2 Methods

=head3 new

	$object = $class->new(%args)

Standard Mooish constructor. Consult L</Attributes> section for available
constructor arguments.

=head3 update

	$res->update()

Updates the internal PAGI scope and sender from the context's PAGI tuple.
Called automatically when the context's PAGI tuple changes via
setter of L<Thunderhorse::Context/pagi>.

=head1 SEE ALSO

L<Thunderhorse>, L<PAGI::Response>, L<Thunderhorse::Context>

