use strict;
use warnings;

use Template::Alloy;
use Test::More tests => 2;

my $t = Template::Alloy->new;

$t->process(\'[% USE foo %]');

is $t->error, 'plugin error - foo: plugin not found';

$t->{PLUGINS}{foo} = 'foo';

$t->process(\'[% USE foo %]');

is $t->error, 'plugin error - foo: plugin not found';
