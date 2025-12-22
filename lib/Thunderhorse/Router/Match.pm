package Thunderhorse::Router::Match;

use v5.40;
use Mooish::Base -standard;

use Devel::StrictMode;

extends 'Gears::Router::Match';

# storing location name instead of object is cache-friendly
has extended 'location' => (
	(STRICT ? (isa => Str) : ()),
);

