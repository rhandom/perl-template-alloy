package Template::Alloy;

###----------------------------------------------------------------###
#  See the perldoc in Template/Alloy.pod
#  Copyright 2007 - Paul Seamons                                     #
#  Distributed under the Perl Artistic License without warranty      #
###----------------------------------------------------------------###

use strict;
use warnings;
use base qw(Exporter);
use Template::Alloy::Exception;
use Template::Alloy::VMethod qw($SCALAR_OPS $FILTER_OPS $LIST_OPS $HASH_OPS $VOBJS);

our $VERSION   = '1.001';
our @EXPORT_OK = qw(@CONFIG_COMPILETIME @CONFIG_RUNTIME
                    $QR_OP $QR_OP_ASSIGN $QR_OP_PREFIX $QR_PRIVATE
                    $OP $OP_ASSIGN $OP_PREFIX $OP_POSTFIX $OP_DISPATCH);

###----------------------------------------------------------------###

our $AUTOLOAD;
our $AUTOROLE = {
    TT       => [qw(parse_tree_tt3 process)],
    Compile  => [qw(load_perl compile_template compile_tree compile_expr compile_expr_flat compile_operator)],
    HTE      => [qw(parse_tree_hte param output register_function clear_param query new_file new_scalar_ref new_array_ref new_filehandle)],
    Parse    => [qw(parse_tree parse_expr apply_precedence parse_args dump_parse dump_parse_expr)],
    Play     => [qw(play_tree list_plugins)],
    Tmpl     => [qw(parse_tree_tmpl set_delimiters set_strip set_value set_values parse_string set_dir parse_file loop_iteration fetch_loop_iteration)],
    Velocity => [qw(parse_tree_velocity merge)],
};
our $AUTOLOOKUP = { map { my $type = $_; map { ($_ => $type) } @{ $AUTOROLE->{$type} } } keys %$AUTOROLE };

sub DESTROY {}
sub AUTOLOAD {
    my $self = shift;
    my $meth = ($AUTOLOAD && $AUTOLOAD =~ /::(\w+)$/) ? $1 : $self->throw('autoload', "Invalid method $AUTOLOAD");
    my $type = delete($AUTOLOOKUP->{$meth})
        || do { require Carp; Carp::croak("Can't locate object method \"$meth\" via package ".ref($self)) };

    my $pkg  = __PACKAGE__."::$type";
    my $file = "$pkg.pm";
    $file =~ s|::|/|g;
    require $file;

    for my $name (@{ $AUTOROLE->{ $type }}) {
        no strict 'refs';
        *{__PACKAGE__."::$name"} = \&{"$pkg\::$name"};
    }

    return $self->$meth(@_);
}

###----------------------------------------------------------------###

our $QR_PRIVATE = qr/^[_.]/;

our $SYNTAX = {
    alloy    => sub { shift->parse_tree_tt3(@_) },
    ht       => sub { my $self = shift; local $self->{'V2EQUALS'} = 0; local $self->{'EXPR'} = 0; $self->parse_tree_hte(@_) },
    hte      => sub { my $self = shift; local $self->{'V2EQUALS'} = 0; $self->parse_tree_hte(@_) },
    tt3      => sub { shift->parse_tree_tt3(@_) },
    tt2      => sub { my $self = shift; local $self->{'V2PIPE'} = 1; $self->parse_tree_tt3(@_) },
    tt1      => sub { my $self = shift; local $self->{'V2PIPE'} = 1; local $self->{'V1DOLLAR'} = 1; $self->parse_tree_tt3(@_) },
    tmpl     => sub { shift->parse_tree_tmpl(@_) },
    velocity => sub { shift->parse_tree_velocity(@_) },
};

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
_build_ops();

our $WHILE_MAX    = 1000;
our $EXTRA_COMPILE_EXT = '.sto';
our $MAX_EVAL_RECURSE  = 50;
our $MAX_MACRO_RECURSE = 50;
our $STAT_TTL          ||= 1;
our $QR_INDEX = '(?:\d*\.\d+ | \d+)';

our @CONFIG_COMPILETIME = qw(SYNTAX ANYCASE INTERPOLATE PRE_CHOMP POST_CHOMP SEMICOLONS V1DOLLAR V2PIPE V2EQUALS AUTO_EVAL SHOW_UNDEFINED_INTERP);
our @CONFIG_RUNTIME     = qw(DUMP VMETHOD_FUNCTIONS);

###----------------------------------------------------------------###

sub new {
  my $class = shift;
  my $args  = ref($_[0]) ? { %{ shift() } } : {@_};

  ### allow for lowercase args
  if (my @keys = grep {/^[a-z][a-z_]+$/} keys %$args) {
      @{ $args }{ map { uc $_ } @keys } = delete @{ $args }{ @keys };
  }

  my $self  = bless $args, $class;

  ### "enable" debugging - we only support DEBUG_DIRS and DEBUG_UNDEF
  if ($self->{'DEBUG'}) {
      $self->{'_debug_dirs'}  = 1 if $self->{'DEBUG'} =~ /^\d+$/ ? $self->{'DEBUG'} & 8 : $self->{'DEBUG'} =~ /dirs|all/;
      $self->{'_debug_undef'} = 1 if $self->{'DEBUG'} =~ /^\d+$/ ? $self->{'DEBUG'} & 2 : $self->{'DEBUG'} =~ /undef|all/;
  }

  return $self;
}

###----------------------------------------------------------------###

sub process_simple {
    my $self = shift;
    my $in   = shift || die "Missing input";
    my $swap = shift || die "Missing variable hash";
    my $out  = shift || die "Missing output string ref";

    eval {
        delete $self->{'_debug_off'};
        delete $self->{'_debug_format'};
        local $self->{'_start_top_level'} = 1;
        $self->_process($in, $swap, $out);
    };
    if (my $err = $@) {
        if ($err->type !~ /stop|return|next|last|break/) {
            $self->{'error'} = $err;
            return;
        }
    }
    return 1;
}

sub _process {
    my $self = shift;
    my $file = shift;
    local $self->{'_vars'} = shift || {};
    my $out_ref = shift || $self->throw('undef', "Missing output ref");
    local $self->{'_top_level'} = delete $self->{'_start_top_level'};
    my $i = length $$out_ref;

    ### parse and execute
    my $doc;
    eval {
        ### handed us a precompiled document
        if (ref($file) eq 'HASH') {
            $doc = $file;

        ### load the document
        } else {
            $doc = $self->load_template($file) || $self->throw('undef', "Zero length content");;
        }

        ### prevent recursion
        $self->throw('file', "recursion into '$doc->{name}'")
            if ! $self->{'RECURSION'} && $self->{'_in'}->{$doc->{'name'}} && $doc->{'name'} ne 'input text';

        local $self->{'_in'}->{$doc->{'name'}} = 1;
        local $self->{'_component'} = $doc;
        local $self->{'_template'}  = $self->{'_top_level'} ? $doc : $self->{'_template'};
        local @{ $self }{@CONFIG_RUNTIME} = @{ $self }{@CONFIG_RUNTIME};

        ### run the document however we can
        if ($doc->{'_perl'}) {
            $doc->{'_perl'}->{'code'}->($self, $out_ref);
        } elsif (! $doc->{'_tree'}) {
            $self->throw('process', 'No _perl and no _tree found');
        } else {
            $self->play_tree($doc->{'_tree'}, $out_ref);
        }

        ### trim whitespace from the beginning and the end of a block or template
        if ($self->{'TRIM'}) {
            substr($$out_ref, $i, length($$out_ref) - $i) =~ s{ \s+ $ }{}x; # tail first
            substr($$out_ref, $i, length($$out_ref) - $i) =~ s{ ^ \s+ }{}x;
        }
    };

    ### handle exceptions
    if (my $err = $@) {
        $err = $self->exception('undef', $err) if ! UNIVERSAL::can($err, 'type');
        $err->doc($doc) if $doc && $err->can('doc') && ! $err->doc;
        die $err if ! $self->{'_top_level'} || $err->type !~ /stop|return/;
    }

    return 1;
}

###----------------------------------------------------------------###

sub load_template {
    my ($self, $file) = @_;

    my $doc;
    if (! defined $file) {
        return;

    ### looks like a scalar ref
    } elsif (ref $file) {
        return $file if ref $file eq 'HASH';

        if (! defined($self->{'CACHE_STR_REFS'}) || $self->{'CACHE_STR_REFS'}) {
            require Digest::MD5;
            my $sum   = Digest::MD5::md5_hex($$file);
            my $_file = 'Alloy_str_ref_cache/'.substr($sum,0,3).'/'.$sum;
            return $self->{'_documents'}->{$_file} if $self->{'_documents'}->{$_file}; # no-ttl necessary
            $doc->{'_filename'} = $_file;
        } else {
            $doc->{'_no_perl'} = $self->{'FORCE_STR_REF_PERL'} ? 0 : 1;
        }
        $doc->{'_content'}    = $file;
        $doc->{'name'}        = 'input text';
        $doc->{'modtime'}     = time;

    ### looks like a previously cached document
    } elsif ($self->{'_documents'}->{$file}) {
        $doc = $self->{'_documents'}->{$file};
        if (time - $doc->{'cache_time'} < ($self->{'STAT_TTL'} || $STAT_TTL) # don't stat more than once a second
            || $doc->{'modtime'} == (stat $doc->{'_filename'})[9]) {         # otherwise see if the file was modified
            $doc->{'_perl'} = $self->load_perl($doc) if ! $doc->{'_perl'} && $self->{'COMPILE_PERL'};
            return $doc;
        }

    ### looks like a previously cached not-found
    } elsif ($self->{'_not_found'}->{$file}) {
        $doc = $self->{'_not_found'}->{$file};
        if (time - $doc->{'cache_time'} < ($self->{'NEGATIVE_STAT_TTL'} || $self->{'STAT_TTL'} || $STAT_TTL)) { # negative cache for a second
            die $doc->{'exception'};
        }
        delete $self->{'_not_found'}->{$file}; # clear cache on failure

    ### looks like a block passed in at runtime
    } elsif ($self->{'BLOCKS'}->{$file}) {
        my $block = $self->{'BLOCKS'}->{$file};
        $block = $block->() if UNIVERSAL::isa($block, 'CODE');
        if (! UNIVERSAL::isa($block, 'HASH')) {
            $self->throw('block', "Unsupported BLOCK type \"$block\"") if ref $block;
            $block = eval { $self->load_template(\$block) } || $self->throw('block', 'Parse error on predefined block');
        }
        $doc->{'name'} = $file;
        if ($block->{'_perl'}) {
            $doc->{'_perl'} = $block->{'_perl'};
        } elsif ($block->{'_tree'}) {
            $doc->{'_tree'} = $block->{'_tree'};
        } else {
            $self->throw('block', "Invalid block definition (missing tree)");
        }
        return $doc;
    }


    ### lookup the filename
    if (! $doc->{'_filename'} && ! ref $file) {
        $doc->{'name'} = $file;
        $doc->{'_filename'} = eval { $self->include_filename($file) };
        if (my $err = $@) {
            ### allow for blocks in other files
            if ($self->{'EXPOSE_BLOCKS'} && ! $self->{'_looking_in_block_file'}) {
                local $self->{'_looking_in_block_file'} = 1;
                my $block_name = '';
              OUTER: while ($file =~ s|/([^/.]+)$||) {
                  $block_name = length($block_name) ? "$1/$block_name" : $1;
                  my $ref = eval { $self->load_template($file) } || next;
                  my $_tree = $ref->{'_tree'};
                  foreach my $node (@$_tree) {
                      last if ! ref $node;
                      next if $node->[0] eq 'META';
                      last if $node->[0] ne 'BLOCK';
                      next if $block_name ne $node->[3];
                      $doc->{'_tree'} = $node->[4];
                      @{$doc}{qw(modtime _content _perl)} = @{$ref}{qw(modtime _content _perl)};
                      return $doc;
                  }
              }
            } elsif ($self->{'DEFAULT'}) {
                $err = '' if ($doc->{'_filename'} = eval { $self->include_filename($self->{'DEFAULT'}) });
            }
            if ($err) {
                ### cache the negative error
                if (! defined($self->{'NEGATIVE_STAT_TTL'}) || $self->{'NEGATIVE_STAT_TTL'}) {
                    $err = $self->exception('undef', $err) if ! UNIVERSAL::can($err, 'type');
                    $self->{'_not_found'}->{$file} = {
                        cache_time => time,
                        exception  => $self->exception($err->type, $err->info." (cached)"),
                    };
                }
                die $err;
            }
        }
    }


    ### return perl - if they want perl - otherwise - the ast
    if (! $doc->{'_no_perl'} && $self->{'COMPILE_PERL'}) {
        $doc->{'_perl'} = $self->load_perl($doc);
    } else {
        $doc->{'_tree'} = $self->load_tree($doc);
    }

    ### cache parsed_tree in memory unless asked not to do so
    if (! defined($self->{'CACHE_SIZE'}) || $self->{'CACHE_SIZE'}) {
        $doc->{'cache_time'} = time;
        if (ref $file) {
            $self->{'_documents'}->{$doc->{'_filename'}} = $doc if $doc->{'_filename'};
        } else {
            $self->{'_documents'}->{$file} ||= $doc;
        }

        ### allow for config option to keep the cache size down
        if ($self->{'CACHE_SIZE'}) {
            my $all = $self->{'_documents'};
            if (scalar(keys %$all) > $self->{'CACHE_SIZE'}) {
                my $n = 0;
                foreach my $file (sort {$all->{$b}->{'cache_time'} <=> $all->{$a}->{'cache_time'}} keys %$all) {
                    delete($all->{$file}) if ++$n > $self->{'CACHE_SIZE'};
                }
            }
        }
    }

    return $doc;
}

sub load_tree {
    my ($self, $doc) = @_;

    ### first look for a compiled optree
    if ($doc->{'_filename'}) {
        $doc->{'modtime'} ||= (stat $doc->{'_filename'})[9];
        if ($self->{'COMPILE_DIR'} || $self->{'COMPILE_EXT'}) {
            my $file = $doc->{'_filename'};
            $file = $doc->{'COMPILE_DIR'} .'/'. $file if $doc->{'COMPILE_DIR'};
            $file .= $self->{'COMPILE_EXT'} if defined($self->{'COMPILE_EXT'});
            $file .= $EXTRA_COMPILE_EXT     if defined $EXTRA_COMPILE_EXT;

            if (-e $file && ($doc->{'_is_str_ref'} || (stat $file)[9] == $doc->{'modtime'})) {
                require Storable;
                return Storable::retrieve($file);
            }
            $doc->{'_storable_filename'} = $file;
        }
    }

    ### no cached tree - we will need to load our own
    $doc->{'_content'} ||= $self->slurp($doc->{'_filename'});

    if ($self->{'CONSTANTS'}) {
        my $key = $self->{'CONSTANT_NAMESPACE'} || 'constants';
        $self->{'NAMESPACE'}->{$key} ||= $self->{'CONSTANTS'};
    }

    local $self->{'_component'} = $doc;
    my $tree = eval { $self->parse_tree($doc->{'_content'}) }
        || do { my $e = $@; $e->doc($doc) if UNIVERSAL::can($e, 'doc') && ! $e->doc; die $e }; # errors die

    ### save a cache on the fileside as asked
    if ($doc->{'_storable_filename'}) {
        my $dir = $doc->{'_storable_filename'};
        $dir =~ s|/[^/]+$||;
        if (! -d $dir) {
            require File::Path;
            File::Path::mkpath($dir);
        }
        require Storable;
        Storable::store($tree, $doc->{'_storable_filename'});
        utime $doc->{'modtime'}, $doc->{'modtime'}, $doc->{'_storable_filename'};
    }

    return $tree;
}

###----------------------------------------------------------------###

### allow for resolving full expression ASTs
sub play_expr {
    ### allow for the parse tree to store literals
    return $_[1] if ! ref $_[1];

    my $self = shift;
    my $var  = shift;
    my $ARGS = shift || {};
    my $i    = 0;

    ### determine the top level of this particular variable access
    my $ref;
    my $name = $var->[$i++];
    my $args = $var->[$i++];
    if (ref $name) {
        if (! defined $name->[0]) { # operator
            return $self->play_operator($name) if wantarray && $name->[1] eq '..';
            $ref = $self->play_operator($name);
        } else { # a named variable access (ie via $name.foo)
            $name = $self->play_expr($name);
            if (defined $name) {
                return if $QR_PRIVATE && $name =~ $QR_PRIVATE; # don't allow vars that begin with _
                return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};
                $ref = $self->{'_vars'}->{$name};
            }
        }
    } elsif (defined $name) {
        return if $QR_PRIVATE && $name =~ $QR_PRIVATE; # don't allow vars that begin with _
        return \$self->{'_vars'}->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $self->{'_vars'}->{$name};
        $ref = $self->{'_vars'}->{$name};
        if (! defined $ref) {
            $ref = ($name eq 'template' || $name eq 'component') ? $self->{"_$name"} : $VOBJS->{$name};
            $ref = $SCALAR_OPS->{$name} if ! $ref && (! defined($self->{'VMETHOD_FUNCTIONS'}) || $self->{'VMETHOD_FUNCTIONS'});
            $ref = $self->{'_vars'}->{lc $name} if ! defined $ref && $self->{'LOWER_CASE_VAR_FALLBACK'};
        }
    }


    my %seen_filters;
    while (defined $ref) {

        ### check at each point if the rurned thing was a code
        if (UNIVERSAL::isa($ref, 'CODE')) {
            return $ref if $i >= $#$var && $ARGS->{'return_ref'};
            my @results = $ref->($args ? map { $self->play_expr($_) } @$args : ());
            if (defined $results[0]) {
                $ref = ($#results > 0) ? \@results : $results[0];
            } elsif (defined $results[1]) {
                die $results[1]; # TT behavior - why not just throw ?
            } else {
                $ref = undef;
                last;
            }
        }

        ### descend one chained level
        last if $i >= $#$var;
        my $was_dot_call = $ARGS->{'no_dots'} ? 1 : $var->[$i++] eq '.';
        $name            = $var->[$i++];
        $args            = $var->[$i++];

        ### allow for named portions of a variable name (foo.$name.bar)
        if (ref $name) {
            if (ref($name) eq 'ARRAY') {
                $name = $self->play_expr($name);
                if (! defined($name) || ($QR_PRIVATE && $name =~ $QR_PRIVATE) || $name =~ /^\./) {
                    $ref = undef;
                    last;
                }
            } else {
                die "Shouldn't get a ". ref($name) ." during a vivify on chain";
            }
        }
        if (! defined $name || ($QR_PRIVATE && $name =~ $QR_PRIVATE)) { # don't allow vars that begin with _
            $ref = undef;
            last;
        }

        ### allow for scalar and filter access (this happens for every non virtual method call)
        if (! ref $ref) {
            if ($SCALAR_OPS->{$name}) {                        # normal scalar op
                $ref = $SCALAR_OPS->{$name}->($ref, $args ? map { $self->play_expr($_) } @$args : ());

            } elsif ($LIST_OPS->{$name}) {                     # auto-promote to list and use list op
                $ref = $LIST_OPS->{$name}->([$ref], $args ? map { $self->play_expr($_) } @$args : ());

            } elsif (my $filter = $self->{'FILTERS'}->{$name}    # filter configured in Template args
                     || $FILTER_OPS->{$name}                     # predefined filters in Alloy
                     || (UNIVERSAL::isa($name, 'CODE') && $name) # looks like a filter sub passed in the stash
                     || $self->list_filters->{$name}) {          # filter defined in Template::Filters

                if (UNIVERSAL::isa($filter, 'CODE')) {
                    $ref = eval { $filter->($ref) }; # non-dynamic filter - no args
                    if (my $err = $@) {
                        $self->throw('filter', $err) if ! UNIVERSAL::can($err, 'type');
                        die $err;
                    }
                } elsif (! UNIVERSAL::isa($filter, 'ARRAY')) {
                    $self->throw('filter', "invalid FILTER entry for '$name' (not a CODE ref)");

                } elsif (@$filter == 2 && UNIVERSAL::isa($filter->[0], 'CODE')) { # these are the TT style filters
                    eval {
                        my $sub = $filter->[0];
                        if ($filter->[1]) { # it is a "dynamic filter" that will return a sub
                            ($sub, my $err) = $sub->($self->context, $args ? map { $self->play_expr($_) } @$args : ());
                            if (! $sub && $err) {
                                $self->throw('filter', $err) if ! UNIVERSAL::can($err, 'type');
                                die $err;
                            } elsif (! UNIVERSAL::isa($sub, 'CODE')) {
                                $self->throw('filter', "invalid FILTER for '$name' (not a CODE ref)")
                                    if ! UNIVERSAL::can($sub, 'type');
                                die $sub;
                            }
                        }
                        $ref = $sub->($ref);
                    };
                    if (my $err = $@) {
                        $self->throw('filter', $err) if ! UNIVERSAL::can($err, 'type');
                        die $err;
                    }
                } else { # this looks like our vmethods turned into "filters" (a filter stored under a name)
                    $self->throw('filter', 'Recursive filter alias \"$name\"') if $seen_filters{$name} ++;
                    $var = [$name, 0, '|', @$filter, @{$var}[$i..$#$var]]; # splice the filter into our current tree
                    $i = 2;
                }
                if (scalar keys %seen_filters
                    && $seen_filters{$var->[$i - 5] || ''}) {
                    $self->throw('filter', "invalid FILTER entry for '".$var->[$i - 5]."' (not a CODE ref)");
                }
            } else {
                $ref = undef;
            }

        } else {

            ### method calls on objects
            if ($was_dot_call && UNIVERSAL::can($ref, 'can')) {
                return $ref if $i >= $#$var && $ARGS->{'return_ref'};
                my @args = $args ? map { $self->play_expr($_) } @$args : ();
                my @results = eval { $ref->$name(@args) };
                if ($@) {
                    my $class = ref $ref;
                    die $@ if ref $@ || $@ !~ /Can\'t locate object method "\Q$name\E" via package "\Q$class\E"/;
                } elsif (defined $results[0]) {
                    $ref = ($#results > 0) ? \@results : $results[0];
                    next;
                } elsif (defined $results[1]) {
                    die $results[1]; # TT behavior - why not just throw ?
                } else {
                    $ref = undef;
                    last;
                }
                # didn't find a method by that name - so fail down to hash and array access
            }

            ### hash member access
            if (UNIVERSAL::isa($ref, 'HASH')) {
                if ($was_dot_call && exists($ref->{$name}) ) {
                    return \ $ref->{$name} if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $ref->{$name};
                    $ref = $ref->{$name};
                } elsif ($HASH_OPS->{$name}) {
                    $ref = $HASH_OPS->{$name}->($ref, $args ? map { $self->play_expr($_) } @$args : ());
                } elsif ($ARGS->{'is_namespace_during_compile'}) {
                    return $var; # abort - can't fold namespace variable
                } else {
                    return \ $ref->{$name} if $i >= $#$var && $ARGS->{'return_ref'};
                    $ref = undef;
                }

            ### array access
            } elsif (UNIVERSAL::isa($ref, 'ARRAY')) {
                if ($name =~ m{ ^ -? $QR_INDEX $ }ox) {
                    return \ $ref->[$name] if $i >= $#$var && $ARGS->{'return_ref'} && ! ref $ref->[$name];
                    $ref = $ref->[$name];
                } elsif ($LIST_OPS->{$name}) {
                    $ref = $LIST_OPS->{$name}->($ref, $args ? map { $self->play_expr($_) } @$args : ());
                } else {
                    $ref = undef;
                }
            }
        }

    } # end of while

    ### allow for undefinedness
    if (! defined $ref) {
        if ($self->{'_debug_undef'}) {
            my $chunk = $var->[$i - 2];
            $chunk = $self->play_expr($chunk) if ref($chunk) eq 'ARRAY';
            die "$chunk is undefined\n";
        } else {
            $ref = $self->undefined_any($var);
        }
    }

    return $ref;
}

### similar to play_expr - but for use with half-resolved names generated by Compile
sub play_variable {
    my $self = shift;
    my $i = 0;

    ### $self->play_variable('bar', [undef, 0, '|', 'fmt', []]); # operates on string containing bar
    my ($var, $name, $ref);
    if (@_ == 2) {
        $ref = shift;
        $var = shift;
        $i++;
    ### $self->play_variable(['foo', 0, '|', 'fmt', []]); # operates on variable foo
    } elsif (@_ == 1) {
        $var  = shift;
        $name = $var->[$i++];

        return if ! defined($name) || ($QR_PRIVATE && $name =~ $QR_PRIVATE); # don't allow vars that begin with _
        $ref = $self->{'_vars'}->{$name};
        if (! defined $ref) {
            $ref = ($name eq 'template' || $name eq 'component') ? $self->{"_$name"} : $VOBJS->{$name};
            $ref = $SCALAR_OPS->{$name} if ! $ref && (! defined($self->{'VMETHOD_FUNCTIONS'}) || $self->{'VMETHOD_FUNCTIONS'});
            $ref = $self->{'_vars'}->{lc $name} if ! defined $ref && $self->{'LOWER_CASE_VAR_FALLBACK'};
        }
    } else {
        $self->throw('play_variable', "Wrong number of args");
    }
    my $args = $var->[$i++];


    my %seen_filters;
    while (defined $ref) {

        ### check at each point if the rurned thing was a code
        if (UNIVERSAL::isa($ref, 'CODE')) {
            my @results = $ref->($args ? @$args : ());
            if (defined $results[0]) {
                $ref = ($#results > 0) ? \@results : $results[0];
            } elsif (defined $results[1]) {
                die $results[1]; # TT behavior - why not just throw ?
            } else {
                $ref = undef;
                last;
            }
        }

        ### descend one chained level
        last if $i >= $#$var;
        my $was_dot_call = $var->[$i++] eq '.';
        $name            = $var->[$i++];
        $args            = $var->[$i++];
        if (! defined $name || ($QR_PRIVATE && $name =~ $QR_PRIVATE)) { # don't allow vars that begin with _
            $ref = undef;
            last;
        }

        ### allow for scalar and filter access (this happens for every non virtual method call)
        if (! ref $ref) {
            if ($SCALAR_OPS->{$name}) {                        # normal scalar op
                $ref = $SCALAR_OPS->{$name}->($ref, $args ? @$args : ());

            } elsif ($LIST_OPS->{$name}) {                     # auto-promote to list and use list op
                $ref = $LIST_OPS->{$name}->([$ref], $args ? @$args : ());

            } elsif (my $filter = $self->{'FILTERS'}->{$name}    # filter configured in Template args
                     || $FILTER_OPS->{$name}                     # predefined filters in Alloy
                     || (UNIVERSAL::isa($name, 'CODE') && $name) # looks like a filter sub passed in the stash
                     || $self->list_filters->{$name}) {          # filter defined in Template::Filters

                if (UNIVERSAL::isa($filter, 'CODE')) {
                    $ref = eval { $filter->($ref) }; # non-dynamic filter - no args
                    if (my $err = $@) {
                        $self->throw('filter', $err) if ! UNIVERSAL::can($err, 'type');
                        die $err;
                    }
                } elsif (! UNIVERSAL::isa($filter, 'ARRAY')) {
                    $self->throw('filter', "invalid FILTER entry for '$name' (not a CODE ref)");

                } elsif (@$filter == 2 && UNIVERSAL::isa($filter->[0], 'CODE')) { # these are the TT style filters
                    eval {
                        my $sub = $filter->[0];
                        if ($filter->[1]) { # it is a "dynamic filter" that will return a sub
                            ($sub, my $err) = $sub->($self->context, $args ? @$args : ());
                            if (! $sub && $err) {
                                $self->throw('filter', $err) if ! UNIVERSAL::can($err, 'type');
                                die $err;
                            } elsif (! UNIVERSAL::isa($sub, 'CODE')) {
                                $self->throw('filter', "invalid FILTER for '$name' (not a CODE ref)")
                                    if ! UNIVERSAL::can($sub, 'type');
                                die $sub;
                            }
                        }
                        $ref = $sub->($ref);
                    };
                    if (my $err = $@) {
                        $self->throw('filter', $err) if ! UNIVERSAL::can($err, 'type');
                        die $err;
                    }
                } else { # this looks like our vmethods turned into "filters" (a filter stored under a name)
                    $self->throw('filter', 'Recursive filter alias \"$name\"') if $seen_filters{$name} ++;
                    $var = [$name, 0, '|', @$filter, @{$var}[$i..$#$var]]; # splice the filter into our current tree
                    $i = 2;
                }
                if (scalar keys %seen_filters
                    && $seen_filters{$var->[$i - 5] || ''}) {
                    $self->throw('filter', "invalid FILTER entry for '".$var->[$i - 5]."' (not a CODE ref)");
                }
            } else {
                $ref = undef;
            }

        } else {

            ### method calls on objects
            if ($was_dot_call && UNIVERSAL::can($ref, 'can')) {
                my @args = $args ? @$args : ();
                my @results = eval { $ref->$name(@args) };
                if ($@) {
                    my $class = ref $ref;
                    die $@ if ref $@ || $@ !~ /Can\'t locate object method "\Q$name\E" via package "\Q$class\E"/;
                } elsif (defined $results[0]) {
                    $ref = ($#results > 0) ? \@results : $results[0];
                    next;
                } elsif (defined $results[1]) {
                    die $results[1]; # TT behavior - why not just throw ?
                } else {
                    $ref = undef;
                    last;
                }
                # didn't find a method by that name - so fail down to hash and array access
            }

            ### hash member access
            if (UNIVERSAL::isa($ref, 'HASH')) {
                if ($was_dot_call && exists($ref->{$name}) ) {
                    $ref = $ref->{$name};
                } elsif ($HASH_OPS->{$name}) {
                    $ref = $HASH_OPS->{$name}->($ref, $args ? @$args : ());
                } else {
                    $ref = undef;
                }

            ### array access
            } elsif (UNIVERSAL::isa($ref, 'ARRAY')) {
                if ($name =~ m{ ^ -? $QR_INDEX $ }ox) {
                    $ref = $ref->[$name];
                } elsif ($LIST_OPS->{$name}) {
                    $ref = $LIST_OPS->{$name}->($ref, $args ? @$args : ());
                } else {
                    $ref = undef;
                }
            }
        }

    } # end of while

    ### allow for undefinedness
    if (! defined $ref) {
        if ($self->{'_debug_undef'}) {
            my $chunk = $var->[$i - 2];
            $chunk = $self->play_expr($chunk) if ref($chunk) eq 'ARRAY';
            die "$chunk is undefined\n";
        } else {
            $ref = $self->undefined_any($var);
        }
    }

    return $ref;
}

sub set_variable {
    my ($self, $var, $val, $ARGS) = @_;
    $ARGS ||= {};
    my $i = 0;

    ### allow for the parse tree to store literals - the literal is used as a name (like [% 'a' = 'A' %])
    $var = [$var, 0] if ! ref $var;

    ### determine the top level of this particular variable access
    my $ref  = $var->[$i++];
    my $args = $var->[$i++];
    if (ref $ref) {
        ### non-named types can't be set
        return if ref($ref) ne 'ARRAY' || ! defined $ref->[0];

        # named access (ie via $name.foo)
        $ref = $self->play_expr($ref);
        if (defined $ref && (! $QR_PRIVATE || $ref !~ $QR_PRIVATE)) { # don't allow vars that begin with _
            if ($#$var <= $i) {
                return $self->{'_vars'}->{$ref} = $val;
            } else {
                $ref = $self->{'_vars'}->{$ref} ||= {};
            }
        } else {
            return;
        }
    } elsif (defined $ref) {
        return if $QR_PRIVATE && $ref =~ $QR_PRIVATE; # don't allow vars that begin with _
        if ($#$var <= $i) {
            return $self->{'_vars'}->{$ref} = $val;
        } else {
            $ref = $self->{'_vars'}->{$ref} ||= {};
        }
    }

    while (defined $ref) {

        ### check at each point if the returned thing was a code
        if (UNIVERSAL::isa($ref, 'CODE')) {
            my @results = $ref->($args ? map { $self->play_expr($_) } @$args : ());
            if (defined $results[0]) {
                $ref = ($#results > 0) ? \@results : $results[0];
            } elsif (defined $results[1]) {
                die $results[1]; # TT behavior - why not just throw ?
            } else {
                return;
            }
        }

        ### descend one chained level
        last if $i >= $#$var;
        my $was_dot_call = $ARGS->{'no_dots'} ? 1 : $var->[$i++] eq '.';
        my $name         = $var->[$i++];
        my $args         = $var->[$i++];

        ### allow for named portions of a variable name (foo.$name.bar)
        if (ref $name) {
            if (ref($name) eq 'ARRAY') {
                $name = $self->play_expr($name);
                if (! defined($name) || $name =~ /^[_.]/) {
                    return;
                }
            } else {
                die "Shouldn't get a ".ref($name)." during a vivify on chain";
            }
        }
        if ($QR_PRIVATE && $name =~ $QR_PRIVATE) { # don't allow vars that begin with _
            return;
        }

        ### scalar access
        if (! ref $ref) {
            return;

        ### method calls on objects
        } elsif (UNIVERSAL::can($ref, 'can')) {
            my $lvalueish;
            my @args = $args ? map { $self->play_expr($_) } @$args : ();
            if ($i >= $#$var) {
                $lvalueish = 1;
                push @args, $val;
            }
            my @results = eval { $ref->$name(@args) };
            if (! $@) {
                if (defined $results[0]) {
                    $ref = ($#results > 0) ? \@results : $results[0];
                } elsif (defined $results[1]) {
                    die $results[1]; # TT behavior - why not just throw ?
                } else {
                    return;
                }
                return if $lvalueish;
                next;
            }
            my $class = ref $ref;
            die $@ if ref $@ || $@ !~ /Can\'t locate object method "\Q$name\E" via package "\Q$class\E"/;
            # fall on down to "normal" accessors
        }

        ### hash member access
        if (UNIVERSAL::isa($ref, 'HASH')) {
            if ($#$var <= $i) {
                return $ref->{$name} = $val;
            } else {
                $ref = $ref->{$name} ||= {};
                next;
            }

        ### array access
        } elsif (UNIVERSAL::isa($ref, 'ARRAY')) {
            if ($name =~ m{ ^ -? $QR_INDEX $ }ox) {
                if ($#$var <= $i) {
                    return $ref->[$name] = $val;
                } else {
                    $ref = $ref->[$name] ||= {};
                    next;
                }
            } else {
                return;
            }

        }

    }

    return;
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

sub _vars {
    my $self = shift;
    $self->{'_vars'} = shift if @_ == 1;
    return $self->{'_vars'} ||= {};
}

sub include_filename {
    my ($self, $file) = @_;
    if ($file =~ m|^/|) {
        $self->throw('file', "$file absolute paths are not allowed (set ABSOLUTE option)") if ! $self->{'ABSOLUTE'};
        return $file if -e $file;
    } elsif ($file =~ m{(^|/)\.\./}) {
        $self->throw('file', "$file relative paths are not allowed (set RELATIVE option)") if ! $self->{'RELATIVE'};
        return $file if -e $file;
    }

    my $paths = $self->{'INCLUDE_PATHS'} ||= do {
        # TT does this everytime a file is looked up - we are going to do it just in time - the first time
        my $paths = $self->{'INCLUDE_PATH'} || [];
        $paths = $paths->()                 if UNIVERSAL::isa($paths, 'CODE');
        $paths = $self->split_paths($paths) if ! UNIVERSAL::isa($paths, 'ARRAY');
        $paths; # return of the do
    };
    foreach my $path (@$paths) {
        return "$path/$file" if -e "$path/$file";
    }

    $self->throw('file', "$file: not found");
}

sub split_paths {
    my ($self, $path) = @_;
    return $path if ref $path;
    my $delim = $self->{'DELIMITER'} || ':';
    $delim = ($delim eq ':' && $^O eq 'MSWin32') ? qr|:(?!/)| : qr|\Q$delim\E|;
    return [split $delim, $path];
}

sub slurp {
    my ($self, $file) = @_;
    open(my $fh, '<', $file) || $self->throw('file', "$file couldn't be opened: $!");
    read $fh, my $txt, -s $file;
    return \$txt;
}

sub error { shift->{'error'} }

###----------------------------------------------------------------###

sub exception {
    my $self = shift;
    my $type = shift;
    my $info = shift;
    return $type if UNIVERSAL::can($type, 'type');
    if (ref($info) eq 'ARRAY') {
        my $hash = ref($info->[-1]) eq 'HASH' ? pop(@$info) : {};
        if (@$info >= 2 || scalar keys %$hash) {
            my $i = 0;
            $hash->{$_} = $info->[$_] for 0 .. $#$info;
            $hash->{'args'} = $info;
            $info = $hash;
        } elsif (@$info == 1) {
            $info = $info->[0];
        } else {
            $info = $type;
            $type = 'undef';
        }
    }
    return Template::Alloy::Exception->new($type, $info, @_);
}

sub throw { die shift->exception(@_) }

sub context {
    my $self = shift;
    require Template::Alloy::Context;
    return Template::Alloy::Context->new({_template => $self});
}

sub iterator {
    my $self = shift;
    require Template::Alloy::Iterator;
    Template::Alloy::Iterator->new(@_);
}

sub undefined_get {
    my ($self, $ident, $node) = @_;
    return $self->{'UNDEFINED_GET'}->($self, $ident, $node) if $self->{'UNDEFINED_GET'};
    return '';
}

sub undefined_any {
    my ($self, $ident) = @_;
    return $self->{'UNDEFINED_ANY'}->($self, $ident) if $self->{'UNDEFINED_ANY'};
    return;
}

sub list_filters {
    my $self = shift;
    return $self->{'_filters'} ||= eval { require Template::Filters; $Template::Filters::FILTERS } || {};
}

sub debug_node {
    my ($self, $node) = @_;
    my $info = $self->node_info($node);
    my $format = $self->{'_debug_format'} || $self->{'DEBUG_FORMAT'} || "\n## \$file line \$line : [% \$text %] ##\n";
    $format =~ s{\$(file|line|text)}{$info->{$1}}g;
    return $format;
}

sub node_info {
    my ($self, $node) = @_;
    my $doc = $self->{'_component'};
    my $i = $node->[1];
    my $j = $node->[2] || return ''; # META can be 0
    $doc->{'_content'} ||= $self->slurp($doc->{'_filename'});
    my $s = substr(${ $doc->{'_content'} }, $i, $j - $i);
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    return {
        file => $doc->{'name'},
        line => $self->get_line_number_by_index($doc, $i),
        text => $s,
    };
}

sub get_line_number_by_index {
    my ($self, $doc, $index, $include_char) = @_;
    return 1 if $index <= 0;

    ### get the line offsets for the doc
    my $lines = $doc->{'_line_offsets'} ||= do {
        $doc->{'_content'} ||= $self->slurp($doc->{'_filename'});
        my $i = 0;
        my @lines = (0);
        while (1) {
            $i = index(${ $doc->{'_content'} }, "\n", $i) + 1;
            last if $i == 0;
            push @lines, $i;
        }
        \@lines;
    };

    ### binary search them (this is fast even on big docs)
    my ($i, $j) = (0, $#$lines);
    if ($index > $lines->[-1]) {
        $i = $j;
    } else {
        while (1) {
            last if abs($i - $j) <= 1;
            my $k = int(($i + $j) / 2);
            $j = $k if $lines->[$k] >= $index;
            $i = $k if $lines->[$k] <= $index;
        }
    }
    return $include_char ? ($i + 1, $index - $lines->[$i]) : $i + 1;
}

###----------------------------------------------------------------###
### long virtual methods or filters
### many of these vmethods have used code from Template/Stash.pm to
### assure conformance with the TT spec.

sub define_syntax {
    my ($self, $name, $sub) = @_;
    $SYNTAX->{$name} = $sub;
    return 1;
}

sub define_operator {
    my ($self, $args) = @_;
    push @$OPERATORS, [@{ $args }{qw(type precedence symbols play_sub)}];
    _build_ops();
    return 1;
}

sub define_directive {
    my ($self, $name, $args) = @_;
    require Template::Alloy::Parse;
    $Template::Alloy::Parse::DIRECTIVES->{$name} = [@{ $args }{qw(parse_sub play_sub is_block is_postop continues no_interp)}];
    return 1;
}

sub define_vmethod {
    my ($self, $type, $name, $sub) = @_;
    if (   $type =~ /scalar|item|text/i) { $SCALAR_OPS->{$name} = $sub }
    elsif ($type =~ /array|list/i ) { $LIST_OPS->{  $name} = $sub }
    elsif ($type =~ /hash/i       ) { $HASH_OPS->{  $name} = $sub }
    elsif ($type =~ /filter/i     ) { $FILTER_OPS->{$name} = $sub }
    else { die "Invalid type vmethod type $type" }
    return 1;
}

###----------------------------------------------------------------###

1;

### See the perldoc in Template/Alloy.pod
