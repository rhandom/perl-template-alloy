#!/usr/bin/perl -w

=head1 NAME

bench_various_templaters.pl - test the relative performance of several different types of template engines.

=cut

use strict;
use Benchmark qw(timethese cmpthese);

use Template;
use Template::Stash;
use Template::Stash::XS;
use Template::Parser::CET;
use Text::Template;
use Text::Tmpl;
use HTML::Template;
use HTML::Template::Compiled;
use HTML::Template::Expr;
use HTML::Template::JIT;
use Template::Alloy;
use Template::Alloy::XS;
use POSIX qw(tmpnam);
use File::Path qw(mkpath rmtree);

###----------------------------------------------------------------###

my $names = {
  TA           => 'Template::Alloy using TT interface',
  TA_NOCACHE   => 'Template::Alloy with string ref caching off',
  TA_P         => 'Template::Alloy - Perl code eval based',
  TA_X         => 'Template::Alloy::XS using TT interface',
  TA_XP        => 'Template::Alloy::XS - Perl code eval based',
  TA_H         => 'Template::Alloy using HTML::Template interface',
  TA_H_X       => 'Template::Alloy::XS using HTML::Template interface',
  TA_H_XP      => 'Template::Alloy::XS using HTML::Template interface - Perl code eval based',
  TA_XTMPL     => 'CGI::Ex::Temmplate::XS using Text::Tmpl interface',
  HT           => 'HTML::Template',
  HTE          => 'HTML::Template::Expr',
  HTJ          => 'HTML::Template::JIT - Compiled to C template',
  HTC          => 'HTML::Template::Compiled',
  TextTemplate => 'Text::Template - Perl code eval based',
  TT           => 'Template::Toolkit',
  TTX          => 'Template::Toolkit with Stash::XS',
  TTXCET       => 'Template::Toolkit with Stash::XS and Template::Parser::CET',
  TMPL         => 'Text::Tmpl - Engine is C based',

  mem          => 'Compiled in memory',
  file         => 'Loaded from file',
  str          => 'From string ref',
};

###----------------------------------------------------------------###
### get cache and compile dirs ready

my $dir  = tmpnam;
my $dir2 = "$dir.cache";
mkpath($dir);
mkpath($dir2);
END {rmtree $dir; rmtree $dir2};
my @dirs = ($dir);

###----------------------------------------------------------------###

my $form = {
  foo => 'bar',
  pass_in_something => 'what ever you want',
};

my $filler = ((" foo" x 10)."\n") x 10;

my $stash_t = {
  shell_header => "This is a header",
  shell_footer => "This is a footer",
  shell_start  => "<html>",
  shell_end    => "<end>",
  a_stuff      => [qw(one two three four)],
};

my $stash_ht = {
  shell_header => "This is a header",
  shell_footer => "This is a footer",
  shell_start  => "<html>",
  shell_end    => "<end>",
  a_stuff      => [map {{name => $_}} qw(one two three four)],
};

$FOO::shell_header = $FOO::shell_footer = $FOO::shell_start = $FOO::shell_end = $FOO::a_stuff;
$FOO::shell_header = "This is a header";
$FOO::shell_footer = "This is a footer";
$FOO::shell_start  = "<html>";
$FOO::shell_end    = "<end>";
$FOO::a_stuff      = [qw(one two three four)];


###----------------------------------------------------------------###
### TT style template

my $content_tt = <<"DOC";
[% shell_header %]
[% shell_start %]
$filler

[% IF foo %]
This is some text.
[% END %]

[% FOREACH i IN a_stuff %][% i %][% END %]
[% pass_in_something %]

$filler
[% shell_end %]
[% shell_footer %]
DOC

if (open (my $fh, ">$dir/foo.tt")) {
    print $fh $content_tt;
    close $fh;
}

###----------------------------------------------------------------###
### HTML::Template style

my $content_ht = <<"DOC";
<TMPL_VAR NAME=shell_header>
<TMPL_VAR NAME=shell_start>
$filler

<TMPL_IF NAME=foo>
This is some text.
</TMPL_IF>

<TMPL_LOOP NAME=a_stuff><TMPL_VAR NAME=name></TMPL_LOOP>
<TMPL_VAR NAME=pass_in_something>

$filler
<TMPL_VAR NAME=shell_end>
<TMPL_VAR NAME=shell_footer>
DOC

if (open (my $fh, ">$dir/foo.ht")) {
    print $fh $content_ht;
    close $fh;
}

###----------------------------------------------------------------###
### Text::Template style template

my $content_p = <<"DOC";
{\$shell_header}
{\$shell_start}
$filler

{ if (\$foo) {
    \$OUT .= "
This is some text.
";
  }
}

{  \$OUT .= \$_ foreach \@\$a_stuff; }
{\$pass_in_something}

$filler
{\$shell_end}
{\$shell_footer}
DOC

###----------------------------------------------------------------###
### Tmpl style template

my $content_tmpl = <<"DOC";
<!--echo \$shell_header-->
<!--echo \$shell_start-->
$filler

<!-- if \$foo -->
This is some text.
<!-- endif -->

<!-- loop "a_stuff" --><!-- echo \$name --><!-- endloop -->
<!-- echo \$pass_in_something -->

$filler
<!-- echo \$shell_end -->
<!-- echo \$shell_footer -->
DOC

if (open (my $fh, ">$dir/foo.tmpl")) {
    print $fh $content_tmpl;
    close $fh;
}

###----------------------------------------------------------------###
### The TT interface allows for a single object to be cached and reused.

my %Alloy_DOCUMENTS;
my %AlloyX_DOCUMENTS;
my %AlloyXP_DOCUMENTS;

my $tt   = Template->new(           INCLUDE_PATH => \@dirs, STASH => Template::Stash->new($stash_t));
my $ttx  = Template->new(           INCLUDE_PATH => \@dirs, STASH => Template::Stash::XS->new($stash_t));
my $ta   = Template::Alloy->new(    INCLUDE_PATH => \@dirs, VARIABLES => $stash_t);
my $tap  = Template::Alloy->new(    INCLUDE_PATH => \@dirs, VARIABLES => $stash_t, COMPILE_PERL => 1);
my $tax  = Template::Alloy::XS->new(INCLUDE_PATH => \@dirs, VARIABLES => $stash_t);
my $taxp = Template::Alloy::XS->new(INCLUDE_PATH => \@dirs, VARIABLES => $stash_t, COMPILE_PERL => 1);

###----------------------------------------------------------------###


my $tests = {

    ###----------------------------------------------------------------###
    ### str infers that we are pulling from a string reference

    TextTemplate_str => sub {
        my $pt = Text::Template->new(
            TYPE   => 'STRING',
            SOURCE => $content_p,
            HASH   => $form);
        my $out = $pt->fill_in(PACKAGE => 'FOO', HASH => $form);
    },

    TT_str => sub {
        my $t = Template->new(STASH => Template::Stash->new($stash_t));
        my $out = ""; $t->process(\$content_tt, $form, \$out); $out;
    },
    TTX_str => sub {
        my $t = Template->new(STASH => Template::Stash::XS->new($stash_t));
        my $out = ""; $t->process(\$content_tt, $form, \$out); $out;
    },
    TTXCET_str => sub {
        my $t = Template->new(STASH => Template::Stash::XS->new($stash_t), PARSER => Template::Parser::CET->new);
        my $out = ""; $t->process(\$content_tt, $form, \$out); $out;
    },
    TA_str => sub {
        my $t = Template::Alloy->new(VARIABLES => $stash_t);
        $t->{'_documents'} = \%Alloy_DOCUMENTS;
        my $out = ""; $t->process(\$content_tt, $form, \$out); $out;
    },
    TA_NOCACHE_str => sub {
        my $t = Template::Alloy->new(VARIABLES => $stash_t, CACHE_STR_REFS => 0);
        my $out = ""; $t->process(\$content_tt, $form, \$out); $out;
    },
    TA_X_str => sub {
        my $t = Template::Alloy::XS->new(VARIABLES => $stash_t);
        $t->{'_documents'} = \%AlloyX_DOCUMENTS;
        my $out = ""; $t->process(\$content_tt, $form, \$out); $out;
    },
    TA_XP_str => sub {
        my $t = Template::Alloy::XS->new(VARIABLES => $stash_t, COMPILE_PERL => 1);
        $t->{'_documents'} = \%AlloyXP_DOCUMENTS;
        my $out = ""; $t->process(\$content_tt, $form, \$out); $out;
    },

    TA_H_str => sub {
        my $t = Template::Alloy->new(    type => 'scalarref', source => \$content_ht, case_sensitve=>1, cache => 1);
        $t->{'_documents'} = \%Alloy_DOCUMENTS;
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    TA_H_X_str => sub {
        my $t = Template::Alloy::XS->new(type => 'scalarref', source => \$content_ht, case_sensitve=>1, cache => 1);
        $t->{'_documents'} = \%AlloyX_DOCUMENTS;
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    TA_H_XP_str => sub {
        my $t = Template::Alloy::XS->new(type => 'scalarref', source => \$content_ht, case_sensitve=>1, COMPILE_PERL => 1, cache => 1);
        $t->{'_documents'} = \%AlloyXP_DOCUMENTS;
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HT_str => sub {
        my $t = HTML::Template->new(       type => 'scalarref', source => \$content_ht, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HTE_str => sub {
        my $t = HTML::Template::Expr->new( type => 'scalarref', source => \$content_ht, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HTC_str => sub {
        my $t = HTML::Template::Compiled->new(type => 'scalarref', source => \$content_ht, case_sensitve=>1, cache => 1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    TMPL_str => sub {
        my $t = Text::Tmpl->new;
        for my $ref (@{ $stash_ht->{'a_stuff'} }) {
            $t->loop_iteration('a_stuff')->set_values($ref);
        }
        $t->set_values($stash_ht);
        $t->set_values($form);
        $t->set_delimiters('<!--','-->');
        $t->set_dir("$dir/");
        $t->set_strip(0);
        my $out = $t->parse_string($content_tmpl);
    },

    ###----------------------------------------------------------------###
    ### compile means item was compiled to optree or perlcode and stored on disk
    ### this should try to load the template from disk each time

    TT_file => sub {
        my $tt = Template->new(INCLUDE_PATH => \@dirs, STASH => Template::Stash->new($stash_t), COMPILE_DIR => $dir2);
        my $out = ""; $tt->process('foo.tt', $form, \$out); $out;
    },
    TTX_file => sub {
        my $tt = Template->new(INCLUDE_PATH => \@dirs, STASH => Template::Stash::XS->new($stash_t), COMPILE_DIR => $dir2);
        my $out = ""; $tt->process('foo.tt', $form, \$out); $out;
    },
    TA_file => sub {
        my $t = Template::Alloy->new(INCLUDE_PATH => \@dirs, VARIABLES => $stash_t, COMPILE_DIR  => $dir2);
        my $out = ''; $t->process('foo.tt', $form, \$out); $out;
    },
    TA_P_file => sub {
        my $t = Template::Alloy->new(INCLUDE_PATH => \@dirs, VARIABLES => $stash_t, COMPILE_DIR => $dir2, COMPILE_PERL => 1);
        my $out = ''; $t->process('foo.tt', $form, \$out); $out;
    },
    TA_X_file => sub {
        my $t = Template::Alloy::XS->new(INCLUDE_PATH => \@dirs, VARIABLES => $stash_t, COMPILE_DIR => $dir2);
        my $out = ''; $t->process('foo.tt', $form, \$out); $out;
    },
    TA_XP_file => sub {
        my $t = Template::Alloy::XS->new(INCLUDE_PATH => \@dirs, VARIABLES => $stash_t, COMPILE_DIR => $dir2, COMPILE_PERL => 1);
        my $out = ''; $t->process('foo.tt', $form, \$out); $out;
    },

    TA_H_file => sub {
        my $t = Template::Alloy->new(type => 'filename', source => "foo.ht", file_cache => 1, path => \@dirs, file_cache_dir => $dir2, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    TA_H_X_file => sub {
        my $t = Template::Alloy::XS->new(type => 'filename', source => "foo.ht", file_cache => 1, path => \@dirs, file_cache_dir => $dir2,
                                            case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    TA_H_XP_file => sub {
        my $t = Template::Alloy::XS->new(type => 'filename', source => "foo.ht", file_cache => 1, path => \@dirs, file_cache_dir => $dir2,
                                         case_sensitve=>1, compile_perl => 1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HT_file => sub {
        my $t = HTML::Template->new(type => 'filename', source => "foo.ht", file_cache => 1, path => \@dirs, file_cache_dir => $dir2, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HTC_file => sub {
        my $t = HTML::Template::Compiled->new(type => 'filename', source => "foo.ht", file_cache => 1, path => \@dirs, file_cache_dir => $dir2, case_sensitve=>1, cache => 0);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
#        $t->clear_cache; # caches in memory by default - can't disable it
#        return $out;
    },
    TMPL_file => sub {
        my $t = Text::Tmpl->new;
        for my $ref (@{ $stash_ht->{'a_stuff'} }) {
            $t->loop_iteration('a_stuff')->set_values($ref);
        }
        $t->set_values($stash_ht);
        $t->set_values($form);
        $t->set_delimiters('<!--','-->');
        $t->set_dir("$dir/");
        $t->set_strip(0);
        my $out = $t->parse_file("foo.tmpl");
    },
    TA_XTMPL_file => sub {
        my $t = Template::Alloy::XS->new;
        for my $ref (@{ $stash_ht->{'a_stuff'} }) {
            $t->loop_iteration('a_stuff')->set_values($ref);
        }
        $t->set_values($stash_ht);
        $t->set_values($form);
        $t->set_delimiters('<!--','-->');
        $t->set_dir("$dir/");
        $t->set_strip(0);
        my $out = $t->parse_file("foo.tmpl");
    },


    ###----------------------------------------------------------------###
    ### mem indicates that the compiled form is stored in memory

    TT_mem    => sub { my $out = ""; $tt->process(  'foo.tt', $form, \$out); $out },
    TTX_mem   => sub { my $out = ""; $ttx->process( 'foo.tt', $form, \$out); $out },
    TA_mem    => sub { my $out = ""; $ta->process(  'foo.tt', $form, \$out); $out },
    TA_X_mem  => sub { my $out = ""; $tax->process( 'foo.tt', $form, \$out); $out },
    TA_XP_mem => sub { my $out = ""; $taxp->process('foo.tt', $form, \$out); $out },
    TA_P_mem  => sub { my $out = ""; $tap->process( 'foo.tt', $form, \$out); $out },

    TA_H_mem => sub {
        my $t = Template::Alloy->new(    filename => "foo.ht", path => \@dirs, cache => 1, case_sensitve=>1);
        $t->{'_documents'} = \%Alloy_DOCUMENTS;
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    TA_H_X_mem => sub {
        my $t = Template::Alloy::XS->new(filename => "foo.ht", path => \@dirs, cache => 1, case_sensitve=>1);
        $t->{'_documents'} = \%AlloyX_DOCUMENTS;
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    TA_H_XP_mem => sub {
        my $t = Template::Alloy::XS->new(filename => "foo.ht", path => \@dirs, cache => 1, case_sensitve=>1, compile_perl => 1, cache => 1);
        $t->{'_documents'} = \%AlloyXP_DOCUMENTS;
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HT_mem => sub {
        my $t = HTML::Template->new(       filename => "foo.ht", path => \@dirs, cache => 1, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HTC_mem => sub {
        my $t = HTML::Template::Compiled->new(       filename => "foo.ht", path => \@dirs, cache => 1, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HTE_mem => sub {
        my $t = HTML::Template::Expr->new( filename => "foo.ht", path => \@dirs, cache => 1, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
    HTJ_mem => sub { # this is interesting - it is compiled - but it is pulled into memory just once
        my $t = HTML::Template::JIT->new(  filename => "foo.ht", path => \@dirs, jit_path => $dir2, case_sensitve=>1);
        $t->param($stash_ht); $t->param($form); my $out = $t->output;
    },
};

my $test = $tests->{'TT_str'}->();
foreach my $name (sort keys %$tests) {
    if ($test ne $tests->{$name}->()) {
        print "--------------------------TT_str-------\n";
        print $test;
        print "--------------------------$name--------\n";
        print $tests->{$name}->();
        die "$name did not match TT_str output\n";
    }
    $name =~ /(\w+)_(\w+)/;
    print "$name - $names->{$1} - ($names->{$2})\n";
}

###----------------------------------------------------------------###
### and now - the tests - grouped by common capability

my %mem_tests = map {my $k=$_; $k=~s/_mem$//;  $k => $tests->{$_}} grep {/_mem$/} keys %$tests;
my %cpl_tests = map {my $k=$_; $k=~s/_file$//; $k => $tests->{$_}} grep {/_file$/} keys %$tests;
my %str_tests = map {my $k=$_; $k=~s/_str$//;  $k => $tests->{$_}} grep {/_str$/} keys %$tests;

print "---STR------------------------------------------------------------------\n";
print "From a string or scalarref tests\n";
cmpthese timethese (-2, \%str_tests);

print "---FILE-----------------------------------------------------------------\n";
print "Compiled and cached on the file system tests\n";
cmpthese timethese (-2, \%cpl_tests);

print "---MEM------------------------------------------------------------------\n";
print "Cached in memory tests\n";
cmpthese timethese (-2, \%mem_tests);

#print "------------------------------------------------------------------------\n";
#print "All variants together\n";
#cmpthese timethese (-2, $tests);

###----------------------------------------------------------------###

__END__

=head1 SAMPLE OUTPUT v2.13

    HTC_file - HTML::Template::Compiled - (Loaded from file)
    HTC_mem - HTML::Template::Compiled - (Compiled in memory)
    HTC_str - HTML::Template::Compiled - (From string ref)
    HTE_mem - HTML::Template::Expr - (Compiled in memory)
    HTE_str - HTML::Template::Expr - (From string ref)
    HTJ_mem - HTML::Template::JIT - Compiled to C template - (Compiled in memory)
    HT_file - HTML::Template - (Loaded from file)
    HT_mem - HTML::Template - (Compiled in memory)
    HT_str - HTML::Template - (From string ref)
    TA_H_XP_file - Template::Alloy::XS using HTML::Template interface - Perl code eval based - (Loaded from file)
    TA_H_XP_mem - Template::Alloy::XS using HTML::Template interface - Perl code eval based - (Compiled in memory)
    TA_H_XP_str - Template::Alloy::XS using HTML::Template interface - Perl code eval based - (From string ref)
    TA_H_X_file - Template::Alloy::XS using HTML::Template interface - (Loaded from file)
    TA_H_X_mem - Template::Alloy::XS using HTML::Template interface - (Compiled in memory)
    TA_H_X_str - Template::Alloy::XS using HTML::Template interface - (From string ref)
    TA_H_file - Template::Alloy using HTML::Template interface - (Loaded from file)
    TA_H_mem - Template::Alloy using HTML::Template interface - (Compiled in memory)
    TA_H_str - Template::Alloy using HTML::Template interface - (From string ref)
    TA_NOCACHE_str - Template::Alloy with string ref caching off - (From string ref)
    TA_P_file - Template::Alloy - Perl code eval based - (Loaded from file)
    TA_P_mem - Template::Alloy - Perl code eval based - (Compiled in memory)
    TA_XP_file - Template::Alloy::XS - Perl code eval based - (Loaded from file)
    TA_XP_mem - Template::Alloy::XS - Perl code eval based - (Compiled in memory)
    TA_XP_str - Template::Alloy::XS - Perl code eval based - (From string ref)
    TA_XTMPL_file - CGI::Ex::Temmplate::XS using Text::Tmpl interface - (Loaded from file)
    TA_X_file - Template::Alloy::XS using TT interface - (Loaded from file)
    TA_X_mem - Template::Alloy::XS using TT interface - (Compiled in memory)
    TA_X_str - Template::Alloy::XS using TT interface - (From string ref)
    TA_file - Template::Alloy using TT interface - (Loaded from file)
    TA_mem - Template::Alloy using TT interface - (Compiled in memory)
    TA_str - Template::Alloy using TT interface - (From string ref)
    TMPL_file - Text::Tmpl - Engine is C based - (Loaded from file)
    TMPL_str - Text::Tmpl - Engine is C based - (From string ref)
    TTXCET_str - Template::Toolkit with Stash::XS and Template::Parser::CET - (From string ref)
    TTX_file - Template::Toolkit with Stash::XS - (Loaded from file)
    TTX_mem - Template::Toolkit with Stash::XS - (Compiled in memory)
    TTX_str - Template::Toolkit with Stash::XS - (From string ref)
    TT_file - Template::Toolkit - (Loaded from file)
    TT_mem - Template::Toolkit - (Compiled in memory)
    TT_str - Template::Toolkit - (From string ref)
    TextTemplate_str - Text::Template - Perl code eval based - (From string ref)
    ---STR------------------------------------------------------------------
    From a string or scalarref tests
    Benchmark: running HT, HTC, HTE, TA, TA_H, TA_H_X, TA_H_XP, TA_NOCACHE, TA_X, TA_XP, TMPL, TT, TTX, TTXCET, TextTemplate for at least 2 CPU seconds...
            HT:  3 wallclock secs ( 2.23 usr +  0.00 sys =  2.23 CPU) @ 1093.72/s (n=2439)
           HTC:  3 wallclock secs ( 2.05 usr +  0.00 sys =  2.05 CPU) @ 195.12/s (n=400)
           HTE:  3 wallclock secs ( 2.20 usr +  0.00 sys =  2.20 CPU) @ 759.09/s (n=1670)
            TA:  3 wallclock secs ( 2.08 usr +  0.01 sys =  2.09 CPU) @ 3210.05/s (n=6709)
          TA_H:  3 wallclock secs ( 2.15 usr +  0.00 sys =  2.15 CPU) @ 3103.26/s (n=6672)
        TA_H_X:  1 wallclock secs ( 2.13 usr +  0.00 sys =  2.13 CPU) @ 4201.88/s (n=8950)
       TA_H_XP:  3 wallclock secs ( 2.11 usr +  0.00 sys =  2.11 CPU) @ 4943.13/s (n=10430)
    TA_NOCACHE:  3 wallclock secs ( 2.15 usr +  0.02 sys =  2.17 CPU) @ 1127.19/s (n=2446)
          TA_X:  2 wallclock secs ( 2.11 usr +  0.00 sys =  2.11 CPU) @ 4861.61/s (n=10258)
         TA_XP:  3 wallclock secs ( 2.12 usr +  0.00 sys =  2.12 CPU) @ 6620.28/s (n=14035)
          TMPL:  3 wallclock secs ( 2.17 usr +  0.02 sys =  2.19 CPU) @ 7552.51/s (n=16540)
            TT:  3 wallclock secs ( 2.21 usr +  0.01 sys =  2.22 CPU) @ 264.41/s (n=587)
           TTX:  3 wallclock secs ( 2.19 usr +  0.01 sys =  2.20 CPU) @ 276.82/s (n=609)
        TTXCET:  3 wallclock secs ( 2.12 usr +  0.00 sys =  2.12 CPU) @ 443.40/s (n=940)
    TextTemplate:  3 wallclock secs ( 2.03 usr +  0.00 sys =  2.03 CPU) @ 1048.28/s (n=2128)
                   Rate   HTC    TT   TTX TTXCET  HTE TextTemplate   HT TA_NOCACHE TA_H   TA TA_H_X TA_X TA_H_XP TA_XP TMPL
    HTC           195/s    --  -26%  -30%   -56% -74%         -81% -82%       -83% -94% -94%   -95% -96%    -96%  -97% -97%
    TT            264/s   36%    --   -4%   -40% -65%         -75% -76%       -77% -91% -92%   -94% -95%    -95%  -96% -96%
    TTX           277/s   42%    5%    --   -38% -64%         -74% -75%       -75% -91% -91%   -93% -94%    -94%  -96% -96%
    TTXCET        443/s  127%   68%   60%     -- -42%         -58% -59%       -61% -86% -86%   -89% -91%    -91%  -93% -94%
    HTE           759/s  289%  187%  174%    71%   --         -28% -31%       -33% -76% -76%   -82% -84%    -85%  -89% -90%
    TextTemplate 1048/s  437%  296%  279%   136%  38%           --  -4%        -7% -66% -67%   -75% -78%    -79%  -84% -86%
    HT           1094/s  461%  314%  295%   147%  44%           4%   --        -3% -65% -66%   -74% -78%    -78%  -83% -86%
    TA_NOCACHE   1127/s  478%  326%  307%   154%  48%           8%   3%         -- -64% -65%   -73% -77%    -77%  -83% -85%
    TA_H         3103/s 1490% 1074% 1021%   600% 309%         196% 184%       175%   --  -3%   -26% -36%    -37%  -53% -59%
    TA           3210/s 1545% 1114% 1060%   624% 323%         206% 193%       185%   3%   --   -24% -34%    -35%  -52% -57%
    TA_H_X       4202/s 2053% 1489% 1418%   848% 454%         301% 284%       273%  35%  31%     -- -14%    -15%  -37% -44%
    TA_X         4862/s 2392% 1739% 1656%   996% 540%         364% 345%       331%  57%  51%    16%   --     -2%  -27% -36%
    TA_H_XP      4943/s 2433% 1769% 1686%  1015% 551%         372% 352%       339%  59%  54%    18%   2%      --  -25% -35%
    TA_XP        6620/s 3293% 2404% 2292%  1393% 772%         532% 505%       487% 113% 106%    58%  36%     34%    -- -12%
    TMPL         7553/s 3771% 2756% 2628%  1603% 895%         620% 591%       570% 143% 135%    80%  55%     53%   14%   --
    ---FILE-----------------------------------------------------------------
    Compiled and cached on the file system tests
    Benchmark: running HT, HTC, TA, TA_H, TA_H_X, TA_H_XP, TA_P, TA_X, TA_XP, TA_XTMPL, TMPL, TT, TTX for at least 2 CPU seconds...
            HT:  3 wallclock secs ( 2.13 usr +  0.06 sys =  2.19 CPU) @ 1715.98/s (n=3758)
           HTC:  3 wallclock secs ( 2.15 usr +  0.01 sys =  2.16 CPU) @ 189.35/s (n=409)
            TA:  4 wallclock secs ( 2.03 usr +  0.08 sys =  2.11 CPU) @ 2228.91/s (n=4703)
          TA_H:  2 wallclock secs ( 1.99 usr +  0.08 sys =  2.07 CPU) @ 2163.77/s (n=4479)
        TA_H_X:  2 wallclock secs ( 1.95 usr +  0.08 sys =  2.03 CPU) @ 2563.05/s (n=5203)
       TA_H_XP:  3 wallclock secs ( 2.03 usr +  0.04 sys =  2.07 CPU) @ 1028.02/s (n=2128)
          TA_P:  3 wallclock secs ( 2.15 usr +  0.06 sys =  2.21 CPU) @ 1158.82/s (n=2561)
          TA_X:  3 wallclock secs ( 2.14 usr +  0.08 sys =  2.22 CPU) @ 3027.03/s (n=6720)
         TA_XP:  3 wallclock secs ( 2.12 usr +  0.05 sys =  2.17 CPU) @ 1335.02/s (n=2897)
      TA_XTMPL:  4 wallclock secs ( 2.17 usr +  0.05 sys =  2.22 CPU) @ 1049.10/s (n=2329)
          TMPL:  2 wallclock secs ( 1.99 usr +  0.20 sys =  2.19 CPU) @ 6136.99/s (n=13440)
            TT:  3 wallclock secs ( 2.13 usr +  0.03 sys =  2.16 CPU) @ 624.54/s (n=1349)
           TTX:  3 wallclock secs ( 2.10 usr +  0.03 sys =  2.13 CPU) @ 741.78/s (n=1580)
               Rate   HTC   TT  TTX TA_H_XP TA_XTMPL TA_P TA_XP   HT TA_H   TA TA_H_X TA_X TMPL
    HTC       189/s    -- -70% -74%    -82%     -82% -84%  -86% -89% -91% -92%   -93% -94% -97%
    TT        625/s  230%   -- -16%    -39%     -40% -46%  -53% -64% -71% -72%   -76% -79% -90%
    TTX       742/s  292%  19%   --    -28%     -29% -36%  -44% -57% -66% -67%   -71% -75% -88%
    TA_H_XP  1028/s  443%  65%  39%      --      -2% -11%  -23% -40% -52% -54%   -60% -66% -83%
    TA_XTMPL 1049/s  454%  68%  41%      2%       --  -9%  -21% -39% -52% -53%   -59% -65% -83%
    TA_P     1159/s  512%  86%  56%     13%      10%   --  -13% -32% -46% -48%   -55% -62% -81%
    TA_XP    1335/s  605% 114%  80%     30%      27%  15%    -- -22% -38% -40%   -48% -56% -78%
    HT       1716/s  806% 175% 131%     67%      64%  48%   29%   -- -21% -23%   -33% -43% -72%
    TA_H     2164/s 1043% 246% 192%    110%     106%  87%   62%  26%   --  -3%   -16% -29% -65%
    TA       2229/s 1077% 257% 200%    117%     112%  92%   67%  30%   3%   --   -13% -26% -64%
    TA_H_X   2563/s 1254% 310% 246%    149%     144% 121%   92%  49%  18%  15%     -- -15% -58%
    TA_X     3027/s 1499% 385% 308%    194%     189% 161%  127%  76%  40%  36%    18%   -- -51%
    TMPL     6137/s 3141% 883% 727%    497%     485% 430%  360% 258% 184% 175%   139% 103%   --
    ---MEM------------------------------------------------------------------
    Cached in memory tests
    Benchmark: running HT, HTC, HTE, HTJ, TA, TA_H, TA_H_X, TA_H_XP, TA_P, TA_X, TA_XP, TT, TTX for at least 2 CPU seconds...
            HT:  3 wallclock secs ( 2.08 usr +  0.03 sys =  2.11 CPU) @ 2428.91/s (n=5125)
           HTC:  3 wallclock secs ( 2.07 usr +  0.01 sys =  2.08 CPU) @ 7590.38/s (n=15788)
           HTE:  3 wallclock secs ( 2.07 usr +  0.03 sys =  2.10 CPU) @ 1379.52/s (n=2897)
           HTJ:  1 wallclock secs ( 2.08 usr +  0.09 sys =  2.17 CPU) @ 5272.35/s (n=11441)
            TA:  3 wallclock secs ( 1.99 usr +  0.05 sys =  2.04 CPU) @ 3432.84/s (n=7003)
          TA_H:  4 wallclock secs ( 2.18 usr +  0.04 sys =  2.22 CPU) @ 3078.38/s (n=6834)
        TA_H_X:  3 wallclock secs ( 2.05 usr +  0.03 sys =  2.08 CPU) @ 4047.12/s (n=8418)
       TA_H_XP:  3 wallclock secs ( 2.04 usr +  0.04 sys =  2.08 CPU) @ 4923.08/s (n=10240)
          TA_P:  3 wallclock secs ( 2.12 usr +  0.03 sys =  2.15 CPU) @ 4148.84/s (n=8920)
          TA_X:  3 wallclock secs ( 2.17 usr +  0.05 sys =  2.22 CPU) @ 5228.83/s (n=11608)
         TA_XP:  3 wallclock secs ( 2.09 usr +  0.04 sys =  2.13 CPU) @ 7544.60/s (n=16070)
            TT:  3 wallclock secs ( 2.15 usr +  0.04 sys =  2.19 CPU) @ 2034.25/s (n=4455)
           TTX:  3 wallclock secs ( 2.14 usr +  0.01 sys =  2.15 CPU) @ 2983.26/s (n=6414)
              Rate  HTE   TT   HT  TTX TA_H   TA TA_H_X TA_P TA_H_XP TA_X  HTJ TA_XP  HTC
    HTE     1380/s   -- -32% -43% -54% -55% -60%   -66% -67%    -72% -74% -74%  -82% -82%
    TT      2034/s  47%   -- -16% -32% -34% -41%   -50% -51%    -59% -61% -61%  -73% -73%
    HT      2429/s  76%  19%   -- -19% -21% -29%   -40% -41%    -51% -54% -54%  -68% -68%
    TTX     2983/s 116%  47%  23%   --  -3% -13%   -26% -28%    -39% -43% -43%  -60% -61%
    TA_H    3078/s 123%  51%  27%   3%   -- -10%   -24% -26%    -37% -41% -42%  -59% -59%
    TA      3433/s 149%  69%  41%  15%  12%   --   -15% -17%    -30% -34% -35%  -54% -55%
    TA_H_X  4047/s 193%  99%  67%  36%  31%  18%     --  -2%    -18% -23% -23%  -46% -47%
    TA_P    4149/s 201% 104%  71%  39%  35%  21%     3%   --    -16% -21% -21%  -45% -45%
    TA_H_XP 4923/s 257% 142% 103%  65%  60%  43%    22%  19%      --  -6%  -7%  -35% -35%
    TA_X    5229/s 279% 157% 115%  75%  70%  52%    29%  26%      6%   --  -1%  -31% -31%
    HTJ     5272/s 282% 159% 117%  77%  71%  54%    30%  27%      7%   1%   --  -30% -31%
    TA_XP   7545/s 447% 271% 211% 153% 145% 120%    86%  82%     53%  44%  43%    --  -1%
    HTC     7590/s 450% 273% 213% 154% 147% 121%    88%  83%     54%  45%  44%    1%   --

=cut
