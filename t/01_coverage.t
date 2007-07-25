# -*- Mode: Perl; -*-

=head1 NAME

01_coverage.t - Test various use cases to make sure the code is exercised for correctness.

=cut

use strict;
use warnings;

use Test::More tests => 23;

###----------------------------------------------------------------###

use_ok('Template::Alloy');

my $o = Template::Alloy->new({foo => 1});
ok($o && $o->{'FOO'}, "Initialize with hashref and get hashref based object");

$o = Template::Alloy->new(foo => 1);
ok($o && $o->{'FOO'}, "Initialize with hash and get hashref based object");

ok(! eval { $o->process_simple } && $@,          "Got an error for process_simple");
ok(! eval { $o->process_simple(\q{wow}) } && $@, "Got an error for process_simple");
ok(! eval { $o->process_simple(\q{wow}, {}) } && $@, "Got an error for process_simple");
my $out = '';
ok($o->process_simple(\q{wow}, {}, \$out) && ! $o->error,           "Ran process_simple without error");

$out = '';
ok(! $o->process_simple(\q{odd[% THROW foo %]interesting}, {}, \$out), "Ran process_simple and threw error");
ok($o->error, "And got error");
ok($out eq 'odd', "Got right output");

$out = '';
ok($o->process_simple(\q{odd[% STOP %]interesting}, {}, \$out), "Ran process_simple and stopped");
ok(! $o->error, "And got no error");
ok($out eq 'odd', "Got right output");

###----------------------------------------------------------------###

$out = '';
ok($o->_process(\q{wow}, undef, \$out), "Ran _process");
ok(! $o->error, "And got error");
ok($out eq 'wow', "Got right output");

ok(! eval { $o->_process(\q{wow}, undef) } && $@, "Ran _process and got error");

$out = '';
ok($o->_process(\q{}, undef, \$out), "Ran _process");
ok(! $o->error, "And got error");
ok($out eq '', "Got right output");

$out = '';
$o->{'_documents'} = {foobar => undef};
ok(! eval { $o->_process('foobar', undef, \$out) }, "Ran _process ($@)");

$out = '';
ok(! eval { $o->_process({name => 'foo'}, undef, \$out) }, "Ran _process ($@)");

$out = '';
ok(eval { $o->_process({name => 'foo', _tree=>['wow']}, undef, \$out) }, "Ran _process");

