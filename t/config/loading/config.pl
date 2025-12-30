return {
	controllers => [
		'^LoadingTestController',
	],
	modules => {
		'^LoadingTestModule' => {
			test_option => 'from_file',
		},
	},
};
