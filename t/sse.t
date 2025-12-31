use v5.40;
use Test2::V1 -ipP;
use Thunderhorse::Test;

use Future::AsyncAwait;

################################################################################
# This tests whether Thunderhorse SSE works
################################################################################

package SSETestApp {
	use Mooish::Base -standard;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		my $router = $self->router;

		$router->add(
			'/simple' => {
				action => 'sse.get',
				to => 'simple',
			}
		);

		$router->add(
			'/json' => {
				action => 'sse.get',
				to => 'json_stream',
			}
		);

		$router->add(
			'/counter' => {
				action => 'sse.get',
				to => 'counter',
			}
		);

		$router->add(
			'/close' => {
				action => 'sse.get',
				to => 'close_test',
			}
		);
	}

	async sub simple ($self, $ctx)
	{
		my $sse = $ctx->sse;

		await $sse->send("hello");
		await $sse->send("world");
	}

	async sub json_stream ($self, $ctx)
	{
		my $sse = $ctx->sse;

		await $sse->send_json({message => 'first', count => 1});
		await $sse->send_json({message => 'second', count => 2});
	}

	async sub counter ($self, $ctx)
	{
		my $sse = $ctx->sse;

		for my $i (1 .. 3) {
			await $sse->send_event(
				data => "Message $i",
				event => 'counter',
				id => $i,
			);
		}
	}

	async sub close_test ($self, $ctx)
	{
		my $sse = $ctx->sse;

		my $closed = false;
		$sse->on_close(sub { $closed = true });

		await $sse->send("start");

		# Wait for close from test side
		while (!$closed) {
			await $self->loop->delay_future(after => 0.1);
		}
	}
};

my $t = Thunderhorse::Test->new(app => SSETestApp->new);

subtest 'should send simple text events' => sub {
	$t->sse_connect('/simple')
		->sse_data_is('hello', 'first message')
		->sse_data_is('world', 'second message')
		->sse_close
		;
};

subtest 'should send json events' => sub {
	$t->sse_connect('/json')
		->sse_json_is({message => 'first', count => 1}, 'first json')
		->sse_json_is({message => 'second', count => 2}, 'second json')
		->sse_close
		;
};

subtest 'should send events with metadata' => sub {
	$t->sse_connect('/counter');

	my $event1 = $t->sse_receive_event;
	is $event1->{data}, 'Message 1', 'first message data';
	is $event1->{event}, 'counter', 'first message event type';
	is $event1->{id}, 1, 'first message id';

	my $event2 = $t->sse_receive_event;
	is $event2->{data}, 'Message 2', 'second message data';
	is $event2->{id}, 2, 'second message id';

	my $event3 = $t->sse_receive_event;
	is $event3->{data}, 'Message 3', 'third message data';
	is $event3->{id}, 3, 'third message id';

	$t->sse_close;
};

subtest 'should handle client disconnect' => sub {
	$t->sse_connect('/close')
		->sse_data_is('start', 'received start message')
		->sse_close
		->sse_closed_ok('connection closed')
		;
};

done_testing;

