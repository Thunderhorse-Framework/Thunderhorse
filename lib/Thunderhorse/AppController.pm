package Thunderhorse::AppController;

use v5.40;
use Mooish::Base -standard;

extends 'Thunderhorse::Controller';
with 'Thunderhorse::Autoloadable';

sub _autoload_from { 'app' }

