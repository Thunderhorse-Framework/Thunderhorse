use v5.40;
use Test2::V1 -ipP;
use Thunderhorse::Test;

use Future::AsyncAwait;

################################################################################
# This tests whether Thunderhorse websockets work
################################################################################

package WebSocketApp {
	use Mooish::Base -standard;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		my $router = $self->router;

		$router->add(
			'/echo' => {
				action => 'websocket.get',
				to => 'echo',
			}
		);

		$router->add(
			'/json' => {
				action => 'websocket.get',
				to => 'json_echo',
			}
		);

		$router->add(
			'/close' => {
				action => 'websocket.get',
				to => 'close_test',
			}
		);
	}

	async sub echo ($self, $ctx)
	{
		my $ws = $ctx->ws;
		await $ws->accept;

		await $ws->each_text(
			async sub ($text) {
				await $ws->send_text("echo: $text");
			}
		);
	}

	async sub json_echo ($self, $ctx)
	{
		my $ws = $ctx->ws;
		await $ws->accept;

		await $ws->each_json(
			async sub ($data) {
				$data->{echoed} = 1;
				await $ws->send_json($data);
			}
		);
	}

	async sub close_test ($self, $ctx)
	{
		my $ws = $ctx->ws;
		await $ws->accept;

		my $msg = await $ws->receive_text;
		await $ws->close(1000, 'goodbye');
	}
};

my $t = Thunderhorse::Test->new(app => WebSocketApp->new);

subtest 'should echo text messages' => sub {
	$t->websocket_connect('/echo')
		->ws_connected_ok('websocket connected')
		->ws_send_text('hello')
		->ws_text_is('echo: hello')
		->ws_send_text('world')
		->ws_text_is('echo: world')
		->websocket_close
		->ws_closed_ok('websocket closed')
		;
};

subtest 'should echo json messages' => sub {
	$t->websocket_connect('/json')
		->ws_connected_ok('websocket connected')
		->ws_send_json({action => 'test', value => 42})
		->ws_json_is({action => 'test', value => 42, echoed => 1})
		->websocket_close
		;
};

subtest 'should handle server initiated close' => sub {
	$t->websocket_connect('/close')
		->ws_send_text('trigger close')
		->ws_closed_ok('server closed connection')
		;
};

done_testing;

