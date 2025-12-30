use v5.40;
use Test2::V1 -ipP;
use Thunderhorse::Test;

################################################################################
# This tests whether Thunderhorse::App loads controllers and modules according
# to the "configure" logic
################################################################################

package LoadingTestController {
	use Mooish::Base -standard;

	extends 'Thunderhorse::Controller';

	sub build ($self)
	{
		$self->router->add(
			'/from-config' => {
				to => 'test',
			}
		);
	}

	sub test ($self, $ctx)
	{
		return 'controller: loaded';
	}
}

package LoadingTestModule {
	use Mooish::Base -standard;

	extends 'Thunderhorse::Module';

	sub build ($self)
	{
		weaken $self;

		$self->register(
			controller => module_method => sub ($controller) {
				return 'module: ' . ($self->config->{test_option} // 'default');
			}
		);
	}
}

package ConfigApp {
	use Mooish::Base -standard;

	extends 'Thunderhorse::App';

	sub build ($self)
	{
		$self->router->add(
			'/module-test' => {
				to => 'test',
			}
		);
	}

	sub test ($self, $ctx)
	{
		return $self->module_method;
	}
}

subtest 'should load controllers from config' => sub {
	my $app = ConfigApp->new(
		initial_config => {
			controllers => [
				'^LoadingTestController',
			],
		},
	);

	my $t = Thunderhorse::Test->new(app => $app);

	$t->request('/from-config')
		->status_is(200)
		->body_is('controller: loaded')
		;
};

subtest 'should load modules from config' => sub {
	my $app = ConfigApp->new(
		initial_config => {
			modules => {
				'^LoadingTestModule' => {
					test_option => 'configured',
				},
			},
		},
	);

	my $t = Thunderhorse::Test->new(app => $app);

	$t->request('/module-test')
		->status_is(200)
		->body_is('module: configured')
		;
};

subtest 'should load both controllers and modules from config' => sub {
	my $app = ConfigApp->new(
		initial_config => {
			controllers => [
				'^LoadingTestController',
			],
			modules => {
				'^LoadingTestModule' => {
					test_option => 'combined',
				},
			},
		},
	);

	my $t = Thunderhorse::Test->new(app => $app);

	$t->request('/from-config')
		->status_is(200)
		->body_is('controller: loaded')
		;

	$t->request('/module-test')
		->status_is(200)
		->body_is('module: combined')
		;
};

subtest 'should load from config file' => sub {
	my $app = ConfigApp->new(
		initial_config => 't/config/loading',
	);

	my $t = Thunderhorse::Test->new(app => $app);

	$t->request('/from-config')
		->status_is(200)
		->body_is('controller: loaded')
		;

	$t->request('/module-test')
		->status_is(200)
		->body_is('module: from_file')
		;
};

subtest 'should handle empty config gracefully' => sub {
	my $app = ConfigApp->new;

	my $t = Thunderhorse::Test->new(app => $app, raise_exceptions => false);

	$t->request('/from-config')
		->status_is(404)
		;

	$t->request('/module-test')
		->status_is(500)
		;
};

done_testing;

