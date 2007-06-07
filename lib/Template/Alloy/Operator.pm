package Template::Alloy::Operator;

=head1 NAME

Template::Alloy::Operator - Storage for operators

=cut

use strict;
use warnings;
use Template::Alloy;
use base qw(Exporter);
our @EXPORT_OK = qw(play_operator define_operator
                    $QR_OP $QR_OP_ASSIGN $QR_OP_PREFIX $QR_PRIVATE
                    $OP $OP_ASSIGN $OP_PREFIX $OP_POSTFIX $OP_DISPATCH);

our $VERSION = $Template::Alloy::VERSION;

###----------------------------------------------------------------###

### setup the operator parsing
our $OPERATORS = [
    # type      precedence symbols              action (undef means play_operator will handle)
    ['prefix',  99,        ['\\'],              undef],
    ['postfix', 98,        ['++'],              undef],
    ['postfix', 98,        ['--'],              undef],
    ['prefix',  97,        ['++'],              undef],
    ['prefix',  97,        ['--'],              undef],
    ['right',   96,        ['**', 'pow'],       sub { no warnings;     $_[0] ** $_[1]  } ],
    ['prefix',  93,        ['!'],               sub { no warnings;   ! $_[0]           } ],
    ['prefix',  93,        ['-'],               sub { no warnings; @_ == 1 ? 0 - $_[0] : $_[0] - $_[1] } ],
    ['left',    90,        ['*'],               sub { no warnings;     $_[0] *  $_[1]  } ],
    ['left',    90,        ['/'],               sub { no warnings;     $_[0] /  $_[1]  } ],
    ['left',    90,        ['div', 'DIV'],      sub { no warnings; int($_[0] /  $_[1]) } ],
    ['left',    90,        ['%', 'mod', 'MOD'], sub { no warnings;     $_[0] %  $_[1]  } ],
    ['left',    85,        ['+'],               sub { no warnings;     $_[0] +  $_[1]  } ],
    ['left',    85,        ['-'],               sub { no warnings; @_ == 1 ? 0 - $_[0] : $_[0] - $_[1] } ],
    ['left',    85,        ['~', '_'],          undef],
    ['none',    80,        ['<'],               sub { no warnings; $_[0] <  $_[1]  } ],
    ['none',    80,        ['>'],               sub { no warnings; $_[0] >  $_[1]  } ],
    ['none',    80,        ['<='],              sub { no warnings; $_[0] <= $_[1]  } ],
    ['none',    80,        ['>='],              sub { no warnings; $_[0] >= $_[1]  } ],
    ['none',    80,        ['lt'],              sub { no warnings; $_[0] lt $_[1]  } ],
    ['none',    80,        ['gt'],              sub { no warnings; $_[0] gt $_[1]  } ],
    ['none',    80,        ['le'],              sub { no warnings; $_[0] le $_[1]  } ],
    ['none',    80,        ['ge'],              sub { no warnings; $_[0] ge $_[1]  } ],
    ['none',    75,        ['=='],              sub { no warnings; $_[0] == $_[1]  } ],
    ['none',    75,        ['eq'],              sub { no warnings; $_[0] eq $_[1]  } ],
    ['none',    75,        ['!='],              sub { no warnings; $_[0] != $_[1]  } ],
    ['none',    75,        ['ne'],              sub { no warnings; $_[0] ne $_[1]  } ],
    ['none',    75,        ['<=>'],             sub { no warnings; $_[0] <=> $_[1] } ],
    ['none',    75,        ['cmp'],             sub { no warnings; $_[0] cmp $_[1] } ],
    ['left',    70,        ['&&'],              undef],
    ['right',   65,        ['||'],              undef],
    ['right',   65,        ['//'],              undef],
    ['none',    60,        ['..'],              sub { no warnings; $_[0] .. $_[1]  } ],
    ['ternary', 55,        ['?', ':'],          undef],
    ['assign',  53,        ['+='],              undef],
    ['assign',  53,        ['-='],              undef],
    ['assign',  53,        ['*='],              undef],
    ['assign',  53,        ['/='],              undef],
    ['assign',  53,        ['%='],              undef],
    ['assign',  53,        ['**='],             undef],
    ['assign',  53,        ['~=', '_='],        undef],
    ['assign',  53,        ['//='],             undef],
    ['assign',  52,        ['='],               undef],
    ['prefix',  50,        ['not', 'NOT'],      sub { no warnings; ! $_[0]         } ],
    ['left',    45,        ['and', 'AND'],      undef],
    ['right',   40,        ['or',  'OR' ],      undef],
    ['right',   40,        ['err', 'ERR'],      undef],
];

our ($QR_OP, $QR_OP_PREFIX, $QR_OP_ASSIGN, $OP, $OP_PREFIX, $OP_DISPATCH, $OP_ASSIGN, $OP_POSTFIX, $OP_TERNARY);
_build_ops();

###----------------------------------------------------------------###

sub _op_qr { # no mixed \w\W operators
    my %used;
    my $chrs = join '|', reverse sort map {quotemeta $_} grep {++$used{$_} < 2} grep {! /\{\}|\[\]/} grep {/^\W{2,}$/} @_;
    my $chr  = join '',          sort map {quotemeta $_} grep {++$used{$_} < 2} grep {/^\W$/}     @_;
    my $word = join '|', reverse sort                    grep {++$used{$_} < 2} grep {/^\w+$/}    @_;
    $chr = "[$chr]" if $chr;
    $word = "\\b(?:$word)\\b" if $word;
    return join('|', grep {length} $chrs, $chr, $word) || die "Missing operator regex";
}

sub _build_ops {
    $QR_OP        = _op_qr(map {@{ $_->[2] }} grep {$_->[0] ne 'prefix'} @$OPERATORS);
    $QR_OP_PREFIX = _op_qr(map {@{ $_->[2] }} grep {$_->[0] eq 'prefix'} @$OPERATORS);
    $QR_OP_ASSIGN = _op_qr(map {@{ $_->[2] }} grep {$_->[0] eq 'assign'} @$OPERATORS);
    $OP           = {map {my $ref = $_; map {$_ => $ref}      @{$ref->[2]}} grep {$_->[0] ne 'prefix' } @$OPERATORS}; # all non-prefix
    $OP_PREFIX    = {map {my $ref = $_; map {$_ => $ref}      @{$ref->[2]}} grep {$_->[0] eq 'prefix' } @$OPERATORS};
    $OP_DISPATCH  = {map {my $ref = $_; map {$_ => $ref->[3]} @{$ref->[2]}} grep {$_->[3]             } @$OPERATORS};
    $OP_ASSIGN    = {map {my $ref = $_; map {$_ => 1}         @{$ref->[2]}} grep {$_->[0] eq 'assign' } @$OPERATORS};
    $OP_POSTFIX   = {map {my $ref = $_; map {$_ => 1}         @{$ref->[2]}} grep {$_->[0] eq 'postfix'} @$OPERATORS}; # bool is postfix
    $OP_TERNARY   = {map {my $ref = $_; map {$_ => 1}         @{$ref->[2]}} grep {$_->[0] eq 'ternary'} @$OPERATORS}; # bool is ternary
}

###----------------------------------------------------------------###

sub play_operator {
    my ($self, $tree) = @_;
    ### $tree looks like [undef, '+', 4, 5]

    return $OP_DISPATCH->{$tree->[1]}->(@$tree == 3 ? $self->play_expr($tree->[2]) : ($self->play_expr($tree->[2]), $self->play_expr($tree->[3])))
        if $OP_DISPATCH->{$tree->[1]};

    my $op = $tree->[1];

    ### do custom and short-circuitable operators
    if ($op eq '=') {
        my $val = $self->play_expr($tree->[3]);
        $self->set_variable($tree->[2], $val);
        return $val;

   } elsif ($op eq '||' || $op eq 'or' || $op eq 'OR') {
        my $val = $self->play_expr($tree->[2]) || $self->play_expr($tree->[3]);
        return defined($val) ? $val : '';

    } elsif ($op eq '&&' || $op eq 'and' || $op eq 'AND') {
        my $val = $self->play_expr($tree->[2]) && $self->play_expr($tree->[3]);
        return defined($val) ? $val : '';

    } elsif ($op eq '//' || $op eq 'err' || $op eq 'ERR') {
        my $val = $self->play_expr($tree->[2]);
        return $val if defined $val;
        return $self->play_expr($tree->[3]);

    } elsif ($op eq '?') {
        no warnings;
        return $self->play_expr($tree->[2]) ? $self->play_expr($tree->[3]) : $self->play_expr($tree->[4]);

    } elsif ($op eq '~' || $op eq '_') {
        no warnings;
        my $s = '';
        $s .= $self->play_expr($tree->[$_]) for 2 .. $#$tree;
        return $s;

    } elsif ($op eq '[]') {
        return [map {$self->play_expr($tree->[$_])} 2 .. $#$tree];

    } elsif ($op eq '{}') {
        no warnings;
        my @e;
        push @e, $self->play_expr($tree->[$_]) for 2 .. $#$tree;
        return {@e};

    } elsif ($op eq '++') {
        no warnings;
        my $val = 0 + $self->play_expr($tree->[2]);
        $self->set_variable($tree->[2], $val + 1);
        return $tree->[3] ? $val : $val + 1; # ->[3] is set to 1 during parsing of postfix ops

    } elsif ($op eq '--') {
        no warnings;
        my $val = 0 + $self->play_expr($tree->[2]);
        $self->set_variable($tree->[2], $val - 1);
        return $tree->[3] ? $val : $val - 1; # ->[3] is set to 1 during parsing of postfix ops

    } elsif ($op eq '\\') {
        my $var = $tree->[2];

        my $ref = $self->play_expr($var, {return_ref => 1});
        return $ref if ! ref $ref;
        return sub { sub { $$ref } } if ref $ref eq 'SCALAR' || ref $ref eq 'REF';

        my $self_copy = $self;
        eval {require Scalar::Util; Scalar::Util::weaken($self_copy)};

        my $last = ['temp deref key', $var->[-1] ? [@{ $var->[-1] }] : 0];
        return sub { sub { # return a double sub so that the current play_expr will return a coderef
            local $self_copy->{'_vars'}->{'temp deref key'} = $ref;
            $last->[-1] = (ref $last->[-1] ? [@{ $last->[-1] }, @_] : [@_]) if @_;
            return $self->play_expr($last);
        } };
    } elsif ($op eq 'qr') {
        return $tree->[3] ? qr{(?$tree->[3]:$tree->[2])} : qr{$tree->[2]};
    }

    $self->throw('operator', "Un-implemented operation $op");
}

###----------------------------------------------------------------###

sub define_operator {
    my ($self, $args) = @_;
    push @$OPERATORS, [@{ $args }{qw(type precedence symbols play_sub)}];
    _build_ops();
    return 1;
}

###----------------------------------------------------------------###

1;
