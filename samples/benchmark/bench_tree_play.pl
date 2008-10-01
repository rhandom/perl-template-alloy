#!/usr/bin/perl -w

=head1 NAME

bench_tree_play.pl - Test various ways of Look at different ways of storing operators and how to call them

=cut

use strict;
use Benchmark qw(cmpthese timethese);
use CGI::Ex::Dump qw(debug);

#my $x = '.';
#my $y = 0;
#my $z = 0;
#my ($nx, $ny, $nz);
#cmpthese timethese -1, {
#    str_eq => sub { $nx++ if '.' eq $x },
#    num_eq => sub { $ny++ if 0 == $y },
#    undef  => sub { $nz++ if ! $z },
#};
##str_eq 6659358/s     --   -21%   -32%
##num_eq 8385413/s    26%     --   -14%
##undef  9799775/s    47%    17%     --

#my $tree1 = [([0, "foo\n"]) x 6];
#my $tree2 = [("foo\n") x 6];
#cmpthese timethese -2, {
#    data => sub { my $t = ''; foreach (@$tree1) { if (! $_->[0]) { $t.= $_->[1] } } },
#    bare => sub { my $t = ''; foreach (@$tree2) { if (! ref $_) { $t .= $_ } } },
#};
##data 254947/s   -- -30%
##bare 364383/s  43%   --

#cmpthese timethese -2, {
#    simple => sub { my $n = [1, 2, 3, "foo", 0] },
#    nested => sub { my $n = [1, 2, 3, ["foo", 0]] },
#};
##nested 511565/s     --   -34%
##simple 774699/s    51%     --

#cmpthese timethese -1, {
#    push_nested => sub { my $n = ["foo", 0]; my $a = [1, 2, 3]; push @$a, $n; $a },
#    index_nested => sub { my $n = ["foo", 0]; my $a = [1, 2, 3]; $a->[3] = $n; $a },
#    set_nested => sub { my $n = ["foo", 0];  my $a = [1, 2, 3, $n]; $a },
#    set_flat => sub { my $n = ["foo", 0]; my $a = [1, 2, 3, @$n]; $a },
#    push_flat => sub { my $n = ["foo", 0]; my $a = [1, 2, 3]; push @$a, @$n; $a },
#    splice_flat => sub { my $n = ["foo", 0]; my $a = [1, 2, 3]; splice(@$a, -1, 0, @$n); $a },
#    reverse_flat => sub { my $n = ["foo", 0]; unshift @$n, 1, 2, 3; $n },
#};
##                 Rate splice_flat push_flat index_nested push_nested set_flat set_nested reverse_flat
##splice_flat  344926/s          --       -3%         -13%        -14%     -17%       -28%         -40%
##push_flat    353975/s          3%        --         -10%        -11%     -15%       -26%         -38%
##index_nested 394568/s         14%       11%           --         -1%      -5%       -17%         -31%
##push_nested  398914/s         16%       13%           1%          --      -4%       -16%         -30%
##set_flat     416210/s         21%       18%           5%          4%       --       -13%         -27%
##set_nested   477203/s         38%       35%          21%         20%      15%         --         -17%
##reverse_flat 573917/s         66%       62%          45%         44%      38%        20%           --

#{
#    package Dispatch;
#    sub play_Foo { my $self = shift }
#    sub Foo { my $self = shift }
#}
#my $DISPATCH1 = {
#    Foo => \&Dispatch::play_Foo,
#};
#my $DISPATCH2 = {
#    Foo => [\&Dispatch::play_Foo],
#};
#my %DISPATCH3 = (
#    Foo => \&Dispatch::play_Foo,
#);
#my $obj = bless {}, 'Dispatch';
#my $type = 'Foo';
#my $nn = 2;
#cmpthese timethese -2, {
#    dispatch1 => sub { $DISPATCH1->{$type}->($obj) },
#    dispatch2 => sub { $DISPATCH2->{$type}->[0]->($obj) },
#    dispatch3 => sub { $DISPATCH3{$type}->($obj) },
#    method1    => sub { $obj->$type() },
#    method2    => sub { my $meth = "play_$type"; $obj->$meth() },
#    method3    => sub { if ($type eq 'Foo') { $obj->play_Foo() } },
#    method4    => sub { my $meth = $obj->can("play_$type"); $meth->($obj) },
#};
##               Rate method4 method2 method3 dispatch2 dispatch1 method1 dispatch3
##method4    625041/s      --    -26%    -44%      -45%      -54%    -54%      -55%
##method2    847328/s     36%      --    -25%      -26%      -38%    -38%      -39%
##method3   1123939/s     80%     33%      --       -1%      -18%    -18%      -19%
##dispatch2 1137400/s     82%     34%      1%        --      -17%    -17%      -18%
##dispatch1 1366860/s    119%     61%     22%       20%        --     -0%       -2%
##method1   1367892/s    119%     61%     22%       20%        0%      --       -2%
##dispatch3 1388950/s    122%     64%     24%       22%        2%      2%        --

#sub _shift {
#    my $self = shift;
#    my $arg1 = shift;
#    my $arg2 = shift;
#}
#sub _array {  my ($self, $arg1, $arg2) = @_; }
#sub _slice {  my ($self, $arg1, $arg2) = @_[0,1,2]; }
#sub _index {
#    my $self = $_[0];
#    my $arg1 = $_[1];
#    my $arg2 = $_[2];
#}
#cmpthese timethese -1, {
#    shift => sub { _shift(1, 2, 3) },
#    array => sub { _array(1, 2, 3) },
#    slice => sub { _slice(1, 2, 3) },
#    index => sub { _index(1, 2, 3) },
#};
##           Rate slice shift index array
##slice  983040/s    --   -5%  -17%  -17%
##shift 1037900/s    6%    --  -12%  -13%
##index 1180322/s   20%   14%    --   -1%
##array 1191563/s   21%   15%    1%    --

#use List::Util qw(first);
#my @scope = ({foo=>2},{},{bar=>3},{},{},{},{},{},{},{baz=>1});
#cmpthese timethese -1, {
#    first_foo => sub { my $ref = (first {exists $_->{foo}} @scope)->{foo} },
#    iter_foo  => sub { my $ref; for (@scope) { next if ! exists $_->{foo}; $ref = $_->{foo}; last } },
#    bare_foo  => sub { my $ref = $scope[0]->{foo} },
#    first_bar => sub { my $ref = (first {exists $_->{bar}} @scope)->{bar} },
#    iter_bar  => sub { my $ref; for (@scope) { next if ! exists $_->{bar}; $ref = $_->{bar}; last } },
#    iter_baz  => sub { my $ref; for (@scope) { next if ! exists $_->{baz}; $ref = $_->{baz}; last } },
#};
##               Rate  iter_baz first_bar first_foo  iter_bar  iter_foo  bare_foo
##iter_baz   265481/s        --      -16%      -30%      -57%      -73%      -91%
##first_bar  315077/s       19%        --      -17%      -49%      -68%      -90%
##first_foo  378300/s       42%       20%        --      -39%      -61%      -88%
##iter_bar   619376/s      133%       97%       64%        --      -36%      -80%
##iter_foo   973307/s      267%      209%      157%       57%        --      -68%
##bare_foo  3084047/s     1062%      879%      715%      398%      217%        --

###----------------------------------------------------------------###

sub tree_new {
    [
    "Hey bird.\n",
    [0, 2, "foo", 0],
    "Hey bird.\n",
    [3, 10, '+', [0, 2, "bar", 0], 2],
    "Hey bird.\n",
    ]
}

sub tree_old {
    [
    "Hey bird.\n",
    ['GET', 2, 3, ["foo", 0]],
    "Hey bird.\n",
    ['GET', 10, 23, [undef, '+', ["bar", 0], 2]],
    "Hey bird.\n",
    ]
}


###----------------------------------------------------------------###

my $DIRECTIVES = {
    GET => \&play_GET,
};

sub play_tree {
    my ($self, $tree, $out_ref) = @_;

    for my $node (@$tree) {
        if (! ref $node) {
            $$out_ref .= $node;
            next;
        }
        $$out_ref .= $self->debug_node($node) if $self->{'_debug_dirs'} && ! $self->{'_debug_off'};
        $DIRECTIVES->{$node->[0]}->($self, $node->[3], $node, $out_ref);
    }
}

sub play_GET {
    my ($self, $ident, $node, $out_ref) = @_;
    my $var = $self->play_expr($ident);
    if (defined $var) {
        $$out_ref .= $var;
    } else {
        $var = $self->undefined_get($ident, $node);
        $$out_ref .= $var if defined $var;
    }
    return;
}

sub play_expr {
    my ($self, $var, $ARGS) = @_;
    return $var if ! ref $var;
    return $self->play_operator($var) if ! $var->[0];
    my $ref =  $self->{'_vars'}->{$var->[0]};
    $ref = $self->undefined_any($var) if ! defined $ref;
    return $ref;
}

our $OPERATORS = [
    # type      precedence symbols              action (undef means play_operator will handle)
    ['left',    85,        ['+'],               sub { no warnings;     $_[0] +  $_[1]  } ],
];
our $OP_DISPATCH  = {map {my $ref = $_; map {$_ => $ref->[3]} @{$ref->[2]}} grep {$_->[3]             } @$OPERATORS};

sub play_operator {
    my ($self, $tree) = @_;
    return $OP_DISPATCH->{$tree->[1]}->(@$tree == 3 ? $self->play_expr($tree->[2]) : ($self->play_expr($tree->[2]), $self->play_expr($tree->[3])))
        if $OP_DISPATCH->{$tree->[1]};
    die;
}

###----------------------------------------------------------------###

my %OP = (
    '+' => \&operator_add,
);

sub play_tree2 {
    my ($self, $tree, $out_ref) = @_;

    for my $node (@$tree) {
        if (! ref $node) {
            $$out_ref .= $node;
            next;
        }
        $$out_ref .= $self->debug_node($node) if $self->{'_debug_dirs'} && ! $self->{'_debug_off'};
        if (! $node->[0]) {
            $$out_ref .= $self->play_expr2($node);
        } elsif ($node->[0] == 3) {
            $$out_ref .= $OP{$node->[2]}->($self, $node);
        } else {
            die;
        }
    }

}

sub play_expr2 {
    my ($self, $var, $ARGS) = @_;
    return $var if ! ref $var;
    my $ref;
    for (@{ $self->{'_scope'} }) {
        next if ! exists $_->{$var->[2]};
        $ref = $_->{$var->[2]};
        last;
    }

    if (! defined $ref) {
        if ($self->{'if_context'}) {
            $ref = $self->undefined_any($var);
        } else {
            $ref = $self->undefined_get($var);
        }
    }
    return $ref;
}

sub operator_add {
    my ($self, $node) = @_;
    no warnings;
    return $self->play_expr2($node->[3]) + $self->play_expr2($node->[4]);
}

###----------------------------------------------------------------###

my $vars = {foo => 2, bar => 3};
my $obj = bless {_vars => $vars, _scope => [$vars]}, __PACKAGE__;

my $case1 = tree_new();
my $case2 = tree_old();

sub old_method {
    my $out = '';
    $obj->play_tree($case2, \$out);
    $out;
}

sub new_method {
    my $out = '';
    $obj->play_tree2($case1, \$out);
    $out;
}

print old_method();
print new_method();

cmpthese timethese -2, {
    old_build => \&tree_old,
    new_build => \&tree_new,
};
#              Rate old_build new_build
#old_build 138369/s        --      -20%
#new_build 172461/s       25%        --

cmpthese timethese -2, {
    old_play => \&old_method,
    new_play => \&new_method,
};
#            Rate old_play new_play
#old_play 50004/s       --     -20%
#new_play 62127/s      24%       --

use Storable qw(freeze thaw);
cmpthese timethese -2, {
    old_freeze => sub { my $n = freeze $case2 },
    new_freeze => sub { my $n = freeze $case1 },
};
#              Rate old_freeze new_freeze
#old_freeze 25280/s         --        -7%
#new_freeze 27120/s         7%         --

my $froze2 = freeze $case2;
my $froze1 = freeze $case1;

cmpthese timethese -2, {
    old_thaw => sub { my $n = thaw $froze2 },
    new_thaw => sub { my $n = thaw $froze1 },
};
#            Rate old_thaw new_thaw
#old_thaw 77193/s       --     -11%
#new_thaw 86809/s      12%       --

