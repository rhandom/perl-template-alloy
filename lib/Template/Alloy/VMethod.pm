package Template::Alloy::VMethod;

=head1 NAME

Template::Alloy::VMethod - Storage for Alloy vmethods.

=cut

use strict;
use warnings;
use Template::Alloy;
use base qw(Exporter);
our @EXPORT_OK = qw(define_vmethod $SCALAR_OPS $FILTER_OPS $LIST_OPS $HASH_OPS $VOBJS);

###----------------------------------------------------------------###

our $SCALAR_OPS = {
    '0'      => sub { $_[0] },
    abs      => sub { no warnings; abs shift },
    atan2    => sub { no warnings; atan2($_[0], $_[1]) },
    chunk    => \&vmethod_chunk,
    collapse => sub { local $_ = $_[0]; s/^\s+//; s/\s+$//; s/\s+/ /g; $_ },
    cos      => sub { no warnings; cos $_[0] },
    defined  => sub { defined $_[0] ? 1 : '' },
    exp      => sub { no warnings; exp $_[0] },
    fmt      => \&vmethod_fmt_scalar,
    'format' => \&vmethod_format,
    hash     => sub { {value => $_[0]} },
    hex      => sub { no warnings; hex $_[0] },
    html     => sub { local $_ = $_[0]; s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g; s/\"/&quot;/g; s/\'/&apos;/g; $_ },
    indent   => \&vmethod_indent,
    int      => sub { no warnings; int $_[0] },
    item     => sub { $_[0] },
    js       => sub { local $_ = $_[0]; return if ! $_; s/\n/\\n/g; s/\r/\\r/g; s/(?<!\\)([\"\'])/\\$1/g; $_ },
    lc       => sub { lc $_[0] },
    lcfirst  => sub { lcfirst $_[0] },
    length   => sub { defined($_[0]) ? length($_[0]) : 0 },
    list     => sub { [$_[0]] },
    log      => sub { no warnings; log $_[0] },
    lower    => sub { lc $_[0] },
    match    => \&vmethod_match,
    new      => sub { defined $_[0] ? $_[0] : '' },
    null     => sub { '' },
    oct      => sub { no warnings; oct $_[0] },
    rand     => sub { no warnings; rand shift },
    remove   => sub { vmethod_replace(shift, shift, '', 1) },
    repeat   => \&vmethod_repeat,
    replace  => \&vmethod_replace,
    search   => sub { my ($str, $pat) = @_; return $str if ! defined $str || ! defined $pat; return $str =~ /$pat/ },
    sin      => sub { no warnings; sin $_[0] },
    size     => sub { 1 },
    split    => \&vmethod_split,
    sprintf  => sub { no warnings; my $pat = shift; sprintf($pat, @_) },
    sqrt     => sub { no warnings; sqrt $_[0] },
    srand    => sub { no warnings; srand $_[0]; '' },
    stderr   => sub { print STDERR $_[0]; '' },
    substr   => \&vmethod_substr,
    trim     => sub { local $_ = $_[0]; s/^\s+//; s/\s+$//; $_ },
    uc       => sub { uc $_[0] },
    ucfirst  => sub { ucfirst $_[0] },
    upper    => sub { uc $_[0] },
    uri      => \&vmethod_uri,
    url      => \&vmethod_url,
};

our $FILTER_OPS = { # generally - non-dynamic filters belong in scalar ops
    eval     => [\&filter_eval, 1],
    evaltt   => [\&filter_eval, 1],
    file     => [\&filter_redirect, 1],
    redirect => [\&filter_redirect, 1],
};

our $LIST_OPS = {
    defined => sub { return 1 if @_ == 1; defined $_[0]->[ defined($_[1]) ? $_[1] : 0 ] },
    first   => sub { my ($ref, $i) = @_; return $ref->[0] if ! $i; return [@{$ref}[0 .. $i - 1]]},
    fmt     => \&vmethod_fmt_list,
    grep    => sub { no warnings; my ($ref, $pat) = @_; [grep {/$pat/} @$ref] },
    hash    => sub { no warnings; my $list = shift; return {@$list} if ! @_; my $i = shift || 0; return {map {$i++ => $_} @$list} },
    import  => sub { my $ref = shift; push @$ref, grep {defined} map {ref eq 'ARRAY' ? @$_ : undef} @_; '' },
    item    => sub { $_[0]->[ $_[1] || 0 ] },
    join    => sub { my ($ref, $join) = @_; $join = ' ' if ! defined $join; no warnings; return join $join, @$ref },
    last    => sub { my ($ref, $i) = @_; return $ref->[-1] if ! $i; return [@{$ref}[-$i .. -1]]},
    list    => sub { $_[0] },
    max     => sub { no warnings; $#{ $_[0] } },
    merge   => sub { my $ref = shift; return [ @$ref, grep {defined} map {ref eq 'ARRAY' ? @$_ : undef} @_ ] },
    new     => sub { no warnings; return [@_] },
    null    => sub { '' },
    nsort   => \&vmethod_nsort,
    pick    => \&vmethod_pick,
    pop     => sub { pop @{ $_[0] } },
    push    => sub { my $ref = shift; push @$ref, @_; return '' },
    reverse => sub { [ reverse @{ $_[0] } ] },
    shift   => sub { shift  @{ $_[0] } },
    size    => sub { no warnings; scalar @{ $_[0] } },
    slice   => sub { my ($ref, $a, $b) = @_; $a ||= 0; $b = $#$ref if ! defined $b; return [@{$ref}[$a .. $b]] },
    sort    => \&vmethod_sort,
    splice  => \&vmethod_splice,
    unique  => sub { my %u; return [ grep { ! $u{$_}++ } @{ $_[0] } ] },
    unshift => sub { my $ref = shift; unshift @$ref, @_; return '' },
};

our $HASH_OPS = {
    defined => sub { return 1 if @_ == 1; defined $_[0]->{ defined($_[1]) ? $_[1] : '' } },
    delete  => sub { my $h = shift; delete @{ $h }{map {defined($_) ? $_ : ''} @_}; '' },
    each    => sub { [%{ $_[0] }] },
    exists  => sub { exists $_[0]->{ defined($_[1]) ? $_[1] : '' } },
    fmt     => \&vmethod_fmt_hash,
    hash    => sub { $_[0] },
    import  => sub { my ($a, $b) = @_; @{$a}{keys %$b} = values %$b if ref($b) eq 'HASH'; '' },
    item    => sub { my ($h, $k) = @_; $k = '' if ! defined $k; $Template::Alloy::QR_PRIVATE && $k =~ $Template::Alloy::QR_PRIVATE ? undef : $h->{$k} },
    items   => sub { [ %{ $_[0] } ] },
    keys    => sub { [keys %{ $_[0] }] },
    list    => \&vmethod_list_hash,
    new     => sub { no warnings; return (@_ == 1 && ref $_[-1] eq 'HASH') ? $_[-1] : {@_} },
    null    => sub { '' },
    nsort   => sub { my $ref = shift; [sort {   $ref->{$a} <=>    $ref->{$b}} keys %$ref] },
    pairs   => sub { [map { {key => $_, value => $_[0]->{$_}} } sort keys %{ $_[0] } ] },
    size    => sub { scalar keys %{ $_[0] } },
    sort    => sub { my $ref = shift; [sort {lc $ref->{$a} cmp lc $ref->{$b}} keys %$ref] },
    values  => sub { [values %{ $_[0] }] },
};

our $VOBJS = {
    Text => $SCALAR_OPS,
    List => $LIST_OPS,
    Hash => $HASH_OPS,
};
foreach (values %$VOBJS) {
    $_->{'Text'} = $_->{'fmt'};
    $_->{'Hash'} = $_->{'hash'};
    $_->{'List'} = $_->{'list'};
}

###----------------------------------------------------------------###
### long virtual methods or filters
### many of these vmethods have used code from Template/Stash.pm to
### assure conformance with the TT spec.

sub define_vmethod {
    my ($self, $type, $name, $sub) = @_;
    if (   $type =~ /scalar|item|text/i) { $SCALAR_OPS->{$name} = $sub }
    elsif ($type =~ /array|list/i ) { $LIST_OPS->{  $name} = $sub }
    elsif ($type =~ /hash/i       ) { $HASH_OPS->{  $name} = $sub }
    elsif ($type =~ /filter/i     ) { $FILTER_OPS->{$name} = $sub }
    else { die "Invalid type vmethod type $type" }
    return 1;
}

sub vmethod_fmt_scalar {
    my $str = shift; $str = ''   if ! defined $str;
    my $pat = shift; $pat = '%s' if ! defined $pat;
    no warnings;
    return @_ ? sprintf($pat, $_[0], $str)
              : sprintf($pat, $str);
}

sub vmethod_fmt_list {
    my $ref = shift || return '';
    my $pat = shift; $pat = '%s' if ! defined $pat;
    my $sep = shift; $sep = ' '  if ! defined $sep;
    no warnings;
    return @_ ? join($sep, map {sprintf $pat, $_[0], $_} @$ref)
              : join($sep, map {sprintf $pat, $_} @$ref);
}

sub vmethod_fmt_hash {
    my $ref = shift || return '';
    my $pat = shift; $pat = "%s\t%s" if ! defined $pat;
    my $sep = shift; $sep = "\n"     if ! defined $sep;
    no warnings;
    return ! @_    ? join($sep, map {sprintf $pat, $_, $ref->{$_}} sort keys %$ref)
         : @_ == 1 ? join($sep, map {sprintf $pat, $_[0], $_, $ref->{$_}} sort keys %$ref) # don't get to pick - it applies to the key
         :           join($sep, map {sprintf $pat, $_[0], $_, $_[1], $ref->{$_}} sort keys %$ref);
}

sub vmethod_chunk {
    my $str  = shift;
    my $size = shift || 1;
    my @list;
    if ($size < 0) { # chunk from the opposite end
        $str = reverse $str;
        $size = -$size;
        unshift(@list, scalar reverse $1) while $str =~ /( .{$size} | .+ )/xg;
    } else {
        push(@list, $1)                   while $str =~ /( .{$size} | .+ )/xg;
    }
    return \@list;
}

sub vmethod_indent {
    my $str = shift; $str = '' if ! defined $str;
    my $pre = shift; $pre = 4  if ! defined $pre;
    $pre = ' ' x $pre if $pre =~ /^\d+$/;
    $str =~ s/^/$pre/mg;
    return $str;
}

sub vmethod_format {
    my $str = shift; $str = ''   if ! defined $str;
    my $pat = shift; $pat = '%s' if ! defined $pat;
    if (@_) {
        return join "\n", map{ sprintf $pat, $_[0], $_ } split(/\n/, $str);
    } else {
        return join "\n", map{ sprintf $pat, $_ } split(/\n/, $str);
    }
}

sub vmethod_list_hash {
    my ($hash, $what) = @_;
    $what = 'pairs' if ! $what || $what !~ /^(keys|values|each|pairs)$/;
    return $HASH_OPS->{$what}->($hash);
}


sub vmethod_match {
    my ($str, $pat, $global) = @_;
    return [] if ! defined $str || ! defined $pat;
    my @res = $global ? ($str =~ /$pat/g) : ($str =~ /$pat/);
    return @res ? \@res : '';
}

sub vmethod_nsort {
    my ($list, $field) = @_;
    return defined($field)
        ? [map {$_->[0]} sort {$a->[1] <=> $b->[1]} map {[$_, (ref $_ eq 'HASH' ? $_->{$field}
                                                               : UNIVERSAL::can($_, $field) ? $_->$field()
                                                               : $_)]} @$list ]
        : [sort {$a <=> $b} @$list];
}

sub vmethod_pick {
    my $ref = shift;
    no warnings;
    my $n   = int(shift);
    $n = 1 if $n < 1;
    my @ind = map { $ref->[ rand @$ref ] } 1 .. $n;
    return $n == 1 ? $ind[0] : \@ind;
}

sub vmethod_repeat {
    my ($str, $n, $join) = @_;
    return '' if ! defined $str || ! length $str;
    $n = 1 if ! defined($n) || ! length $n;
    $join = '' if ! defined $join;
    return join $join, ($str) x $n;
}

### This method is a combination of my submissions along
### with work from Andy Wardley, Sergey Martynoff, Nik Clayton, and Josh Rosenbaum
sub vmethod_replace {
    my ($text, $pattern, $replace, $global) = @_;
    $text      = '' unless defined $text;
    $pattern   = '' unless defined $pattern;
    $replace   = '' unless defined $replace;
    $global    = 1  unless defined $global;
    my $expand = sub {
        my ($chunk, $start, $end) = @_;
        $chunk =~ s{ \\(\\|\$) | \$ (\d+) }{
            $1 ? $1
                : ($2 > $#$start || $2 == 0) ? ''
                : substr($text, $start->[$2], $end->[$2] - $start->[$2]);
        }exg;
        $chunk;
    };
    if ($global) {
        $text =~ s{$pattern}{ $expand->($replace, [@-], [@+]) }eg;
    } else {
        $text =~ s{$pattern}{ $expand->($replace, [@-], [@+]) }e;
    }
    return $text;
}

sub vmethod_sort {
    my ($list, $field) = @_;
    return defined($field)
        ? [map {$_->[0]} sort {$a->[1] cmp $b->[1]} map {[$_, lc(ref $_ eq 'HASH' ? $_->{$field}
                                                                 : UNIVERSAL::can($_, $field) ? $_->$field()
                                                                 : $_)]} @$list ]
        : [map {$_->[0]} sort {$a->[1] cmp $b->[1]} map {[$_, lc $_]} @$list ]; # case insensitive
}

sub vmethod_splice {
    my ($ref, $i, $len, @replace) = @_;
    @replace = @{ $replace[0] } if @replace == 1 && ref $replace[0] eq 'ARRAY';
    if (defined $len) {
        return [splice @$ref, $i || 0, $len, @replace];
    } elsif (defined $i) {
        return [splice @$ref, $i];
    } else {
        return [splice @$ref];
    }
}

sub vmethod_split {
    my ($str, $pat, $lim) = @_;
    $str = '' if ! defined $str;
    if (defined $lim) { return defined $pat ? [split $pat, $str, $lim] : [split ' ', $str, $lim] }
    else              { return defined $pat ? [split $pat, $str      ] : [split ' ', $str      ] }
}

sub vmethod_substr {
    my ($str, $i, $len, $replace) = @_;
    $i ||= 0;
    return substr($str, $i)       if ! defined $len;
    return substr($str, $i, $len) if ! defined $replace;
    substr($str, $i, $len, $replace);
    return $str;
}

sub vmethod_uri {
    my $str = shift;
    utf8::encode($str) if defined &utf8::encode;
    $str =~ s/([^A-Za-z0-9\-_.!~*\'()])/sprintf('%%%02X', ord($1))/eg;
    return $str;
}

sub vmethod_url {
    my $str = shift;
    utf8::encode($str) if defined &utf8::encode;
    $str =~ s/([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*\'()])/sprintf('%%%02X', ord($1))/eg;
    return $str;
}

sub filter_eval {
    my $context = shift;
    my $args    = pop || {};

    return sub {
        ### prevent recursion
        my $t = $context->_template;
        local $t->{'_eval_recurse'} = $t->{'_eval_recurse'} || 0;
        $context->throw('eval_recurse', "MAX_EVAL_RECURSE $Template::Alloy::MAX_EVAL_RECURSE reached")
            if ++$t->{'_eval_recurse'} > ($t->{'MAX_EVAL_RECURSE'} || $Template::Alloy::MAX_EVAL_RECURSE);


        my $text = shift;
        local @{ $t }{ map {uc} keys %$args } = values %$args;
        return $context->process(\$text);
    };
}

sub filter_redirect {
    my ($context, $file, $options) = @_;
    my $path = $context->config->{'OUTPUT_PATH'} || $context->throw('redirect', 'OUTPUT_PATH is not set');
    $context->throw('redirect', 'Invalid filename - cannot include "/../"')
        if $file =~ m{(^|/)\.\./};

    return sub {
        my $text = shift;
        if (! -d $path) {
            require File::Path;
            File::Path::mkpath($path) || $context->throw('redirect', "Couldn't mkpath \"$path\": $!");
        }
        open (my $fh, '>', "$path/$file") || $context->throw('redirect', "Couldn't open \"$file\": $!");
        if (my $bm = (! $options) ? 0 : ref($options) ? $options->{'binmode'} : $options) {
            if (+$bm == 1) { binmode $fh }
            else { binmode $fh, $bm}
        }
        print $fh $text;
        return '';
    };
}

###----------------------------------------------------------------###

1;
