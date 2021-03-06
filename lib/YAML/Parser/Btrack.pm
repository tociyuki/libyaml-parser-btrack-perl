package YAML::Parser::Btrack;
use strict;
use warnings;
use Carp;
use Exporter;

our $VERSION = '0.011';
# $Id$

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    derivs match end_of_file l_yaml_stream s_l__block_node ns_flow_node
);

# CAUTION: This module is highly EXPERIMENTAL!
# do not use for any productions.

# Pieces of the partially memorized backtrak parser.

# derivs is an immutable set of source string and parsing position.
#
#   see the first simple backtrack parser explained in the paper:
#     http://pdos.csail.mit.edu/~baford/packrat/icfp02/
#
# usage:
#   derivs($scalar) => $derivs
#   derivs(\$scalar) => $derivs
#   derivs($derivs, $int) => $derivs
sub derivs {
    my($s, $p) = @_;
    $p ||= 0;
    return [\$s, $p, {}] if ! ref $s;
    return [$s, $p, {}] if ref $s eq 'SCALAR';
    return [$s->[0], $p, $s->[2]] if ref $s eq 'ARRAY';
    Carp::confess('ArgumentError: derivs.');
}

# match phrase (scalar or regexp) parsing position.
# returns ($derivs, @captures);
sub match {
    my($derivs, $phrase) = @_;
    ref $derivs eq 'ARRAY' or Carp::confess('not derivs');
    my($src, $pos, @v) = @{$derivs};
    if (! ref $phrase) {
        my $n = length $phrase;
        if ($phrase eq substr ${$src}, $pos, $n) {
            my $derived = [$src, $pos + $n, @v];
            return wantarray ? ($derived, $phrase) : $derived;
        }
    }
    elsif (ref $phrase eq 'Regexp') {
        pos(${$derivs->[0]}) = $pos;
        if (${$src} =~ m{\G$phrase}gcmsx) {
            my @captures = map {
                defined $-[$_]
                ? (substr ${$src}, $-[$_], $+[$_] - $-[$_])
                : undef;
            } 1 .. $#-;
            my $derived = [$src, pos ${$src}, @v];
            return wantarray ? ($derived, @captures) : $derived;
        }
    }
    return;
}

# at end of file and returns derivs.
sub end_of_file {
    my($derivs) = @_;
    return wantarray ? ($derivs, q()) : 1
        if $derivs->[1] == length ${$derivs->[0]};
    return;
}

# memory parsed result for parsing locations with key.
sub memorize {
    my($derivs, $key, $yield) = @_;
    if (! exists $derivs->[2]{$derivs->[1]}{$key}) {
        $derivs->[2]{$derivs->[1]}{$key} = $yield->() || undef;
    }
    my $parsed = $derivs->[2]{$derivs->[1]}{$key} or return;
    return wantarray ? @{$parsed} : $parsed->[0];
}

# YAML 1.2 Backtrack Parser
#
#   see http://www.yaml.org/spec/1.2/spec.html
#
# In current version, the parser memorizes parsed results of
# flow nodes and separators. To get same results as many as
# possible for productions, the flow nodes and the separators
# are parsed only in the multi-line contexts, flow-in and flow-out.
#
# [39] ns-uri-char
my $URICHAR = qr{(?:%[[:xdigit:]]{2}|[0-9A-Za-z\-\#;/?:\@&=+\$,_.!~*'()\[\]])}msx;
# [40] ns-tag-char
my $TAGCHAR = qr{(?:%[[:xdigit:]]{2}|[0-9A-Za-z\-\#;/?:\@&=+\$_.~*'()])}msx;

# 6.2. Separation Spaces
#
# [66] s-separate-in-line
#
# for s-separate-in-line? C<< match($derivs, qr/([ \t]*)/msx); >>.
sub s_separate_in_line {
    my($derivs) = @_;
    return memorize($derivs, 's-separate-in-line', sub{
        my $derivs1 = match($derivs, qr/[ \t]+|^/omsx) or return;
        return [$derivs1, ['s-separate-in-line']];
    });
}

# [69] s-flow-line-prefix(n)
sub s_flow_line_prefix {
    my($d0, $n) = @_;
    return memorize($d0, 's-flow-line-prefix', sub{
        my $d1 = match($d0, qr/[ ]{$n}[ \t]*/msx) or return;
        return [$d1, ['s-flow-line-prefix']];
    });
}

# 6.6. Comments
#
# [77] s-b-comment
my $S_B_COMMENT = qr/(?:(?:[ \t]+|^)(?:\#[ \t\p{Graph}]*)?)?(?:\n|\z)/msx;

# Regexp stub function for tests.
sub s_b_comment {
    my($derivs) = @_;
    my $derivs1 = match($derivs, $S_B_COMMENT) or return;
    return ($derivs1, ['s_b_comment']);
}

# [78] l-comment
my $L_COMMENT = qr{
    [ \t]*(?:\#[ \t\p{Graph}]*)?
    (?:\n[ \t]*(?:\#[ \t\p{Graph}]*)?)*(?:\n|\z)
}msx;
# [79] s-l-comments
my $S_L_COMMENTS = qr{(
    (?:(?:[ \t]+|^)(?:\#[ \t\p{Graph}]*)?)?
    (?: (?:\n[ \t]*(?:\#[ \t\p{Graph}]*)?)*(?:\n|^|\z)
    |   \z)
)}msx;

sub s_l_comments {
    my($derivs) = @_;
    return memorize($derivs, 's-l-comments', sub{
        my($derivs1, $s) = match($derivs, $S_L_COMMENTS) or return;
        my $line = 0 <= (index $s, "\n") ? 'n' : 'w';
        return [$derivs1, ['s-l-comments'], $line];
    });
}

# 6.7. Separation Lines
#
# [80] s-separate(n,c)
sub s_separate {
    my($derivs, $n, $c) = @_;
    my($derivs3, $v3, $line3) = memorize($derivs, "s-separate($n)", sub{
        my($derivs1, $slcomment, $line) = s_l_comments($derivs);
        if ($derivs1) {
            my $derivs2 = s_flow_line_prefix($derivs1, $n) or return;
            return [$derivs2, ['s-separate'], $line] if $derivs2;
        }
        my $derivs2 = s_separate_in_line($derivs) or return;
        return [$derivs2, ['s-separate'], 'w'];
    }) or return;
    if ($c eq 'block-key' || $c eq 'flow-key') {
        return if $line3 eq 'n';
    }
    return wantarray ? ($derivs3, $v3) : $derivs3;
}

# 6.8. Directives

# [83] ns-reserved-directive
my $NS_RESERVED_DIRECTIVE =
    qr/([^\P{Graph}\#]\p{Graph}*(?:[ \t]+[^\P{Graph}\#]\p{Graph}*)*)/msx;
# [87] ns-yaml-version
my $NS_YAML_VERSION = qr/([0-9]+[.][0-9]+)/msx;
# [89] c-tag-handle
my $C_TAG_HANDLE = qr/([!](?:[!]|[0-9A-Za-z-]+[!])?)/msx;
# [93] ns-tag-prefix
my $NS_TAG_PREFIX = qr/([!]$URICHAR* | $TAGCHAR $URICHAR*)/msx;

# [82] l-directive
sub l_directive {
    my($derivs) = @_;
    my($derivs1) = match($derivs, '%') or return;
    RULE: {
        my($derivs2, $name) = match($derivs1, 'YAML') or last;
        my($derivs3) = s_separate_in_line($derivs2) or return;
        my($derivs4, $ver) = match($derivs3, $NS_YAML_VERSION) or return;
        my($derivs5) = s_l_comments($derivs4) or return;
        return ($derivs5, ['ns-yaml-directive', $name, $ver]); 
    }
    RULE: {
        my($derivs2, $name) = match($derivs1, 'TAG') or last;
        my($derivs3) = s_separate_in_line($derivs2) or return;
        my($derivs4, $handle) = match($derivs3, $C_TAG_HANDLE) or return;
        my($derivs5) = s_separate_in_line($derivs4) or return;
        my($derivs6, $prefix) = match($derivs5, $NS_TAG_PREFIX) or return;
        my($derivs7) = s_l_comments($derivs6) or return;
        return ($derivs7, ['ns-tag-directive', $name, $handle, $prefix]);
    }
    RULE: {
        my($derivs2, $list) = match($derivs1, $NS_RESERVED_DIRECTIVE) or last;
        my($derivs3) = s_l_comments($derivs2) or return;
        return ($derivs3, ['ns-reserved-directive', split /[ \t]+/msx, $list]);
    }
    return;
}

# 6.9. Node Properties
#
# [96] c-ns-properties(n,c)
sub c_ns_properties {
    my($derivs, $n, $c) = @_;
    my($derivs1, $tag, $derivs2, $anchor);
    RULE: {
        ($derivs1, $tag) = c_ns_tag_property($derivs) or last;
        $derivs1
        and $derivs2 = s_separate($derivs1, $n, $c)
        and ($derivs2, $anchor) = c_ns_anchor_property($derivs2);
        return ($derivs2 || $derivs1, ['c-ns-properties', $tag, $anchor]);
    }
    RULE: {
        ($derivs1, $anchor) = c_ns_anchor_property($derivs) or last;
        $derivs1
        and $derivs2 = s_separate($derivs1, $n, $c)
        and ($derivs2, $tag) = c_ns_tag_property($derivs2);
        return ($derivs2 || $derivs1, ['c-ns-properties', $tag, $anchor]);
    }
    return;
}

# [97] c-ns-tag-property
my $C_NS_TAG_PROPERTY = qr{
    ([!] (?:<$URICHAR+> | (?:[!]|[0-9A-Za-z-]+[!])?$TAGCHAR+)?)
}msx;

sub c_ns_tag_property {
    my($derivs) = @_;
    return memorize($derivs, 'c-ns-tag-property', sub{
        my($derivs1, $tag) = match($derivs, $C_NS_TAG_PROPERTY) or return;
        return [$derivs1, ['c-ns-tag-property', $tag]];
    });
}

# [101] c-ns-anchor-property
my $C_NS_ANCHOR_PROPERTY = qr{(&[^\P{Graph},\[\]\{\}]+)}msx;

sub c_ns_anchor_property {
    my($derivs) = @_;
    return memorize($derivs, 'c-ns-anchor-property', sub{
        my($derivs1, $anchor) =
            match($derivs, $C_NS_ANCHOR_PROPERTY) or return;
        return [$derivs1, ['c-ns-anchor-property', $anchor]];
    });
}

# 7.1. Alias Nodes
#
# [104] c-ns-alias-node
sub c_ns_alias_node {
    my($derivs) = @_;
    my $lex = qr/([*][^\P{Graph},\[\]\{\}]+)/msx;
    my($derivs1, $alias) = match($derivs, $lex) or return;
    return ($derivs1, ['c-ns-alias-node', $alias]);
}

# 7.3. Flow Scalar Styles
#
# [109] c-double-quoted(n,c)
sub c_double_quoted {
    my($derivs, $n, $c) = @_;
    $n >= 0 or Carp::confess("c-double-quoted(n,c): n >= 0, but $n.");
    my($derivs1) = match($derivs, q(")) or return;
    my $lex = qr{(
        [^\P{Graph}"\\]*
        (?: (?: [ \t]+
            |   \n(?:[ ]{$n}[ \t]*|[ ]*(?=[\n"]))
            |   \\[0abt\tnvfre "/\\N_LPxuU\n] )
            [^\P{Graph}"\\]* )*
    )}msx;
    my($derivs2, $text) = match($derivs1, $lex) or return;
    my($derivs3) = match($derivs2, q(")) or return;
    return ($derivs3, ['c-double-quoted', decode_double_text($text)]);
}

# [41] to [62] c-ns-esc-char
my %UNESCAPE = (
    '0' => "\x00", 'a' => "\x07", 'b' => "\x08", 't' => "\t", "\t" => "\t",
    'n' => "\n", 'v' => "\x0b", 'f' => "\f", 'r' => "\r", 'e' => "\e",
    q( ) => q( ), q(") => q("), q(/) => q(/), "\\" => "\\",
    'N' => "\x{0085}", '_' => "\x{00a0}", 'L' => "\x{2028}", 'P' => "\x{2029}",
);

# decode_double_text: (Str)->Str
#
# unescapes c-ns-esc-char and
# folds lines as s-double-escaped or s-flow-folded in nb-double-multi-line.
#
#   $s isa Str ns-plain-multi-line
#
sub decode_double_text {
    my($s) = @_;
    $s =~ s{
        ([ \t]*)
        (?: \\
            (?: ([0abt\tnvfre "/\\N_LP])
            |   x([[:xdigit:]]{2}) | u([[:xdigit:]]{4}) | U([[:xdigit:]]{8})
            |   \n((?:[ \t]*\n)*)[ \t]*
            |   (.) )
        |   \n ((?:[ \t]*\n)*)[ \t]* )
    }{
        defined $2 ? $1 . $UNESCAPE{$2}
        : defined $3 ? $1 . (chr hex $3)
        : defined $4 ? $1 . (chr hex $4)
        : defined $5 ? $1 . (chr hex $5)
        : defined $6 ? $1 . ("\n" x ((my $x = $6) =~ tr/\n/\n/))
        : defined $7 ? croak 'SyntaxError: invalid escape characters'
        : defined $8 ? ("\n" x ((my $y = $8) =~ tr/\n/\n/)) || q( )
        : $1
    }egomsx;
    return $s;
}

# [120] c-single-quoted(n,c)
sub c_single_quoted {
    my($derivs, $n, $c) = @_;
    $n >= 0 or Carp::confess("c-single-quoted(n,c): n >= 0, but $n.");
    my($derivs1) = match($derivs, q(')) or return;
    my $lex = qr{(
        [^\P{Graph}']*
        (?: (?: [ \t]+
            |   \n(?:[ ]{$n}[ \t]*|[ ]*(?=[\n"]))
            |   '' )
            [^\P{Graph}']* )*
    )}msx;;
    my($derivs2, $text) = match($derivs1, $lex) or return;
    my($derivs3) = match($derivs2, q(')) or return;
    return ($derivs3, ['c-single-quoted', decode_single_text($text)]);
}

# decode_single_text: (Str)->Str
#
# unescapes c-quoted-quote and 
# folds lines as s_flow_folded in nb-single-multi-line.
#
#   $s isa Str ns-plain-multi-line
#
sub decode_single_text {
    my($s) = @_;
    $s =~ s{
        (?:('')|[ \t]*\n((?:[ \t]*\n)*)[  \t]*)
    }{
        $1 ? q(') : ("\n" x ((my $x = $2) =~ tr/\n/\n/)) || q( )
    }egomsx;
    return $s;
}

# [127] ns-plain-safe(c)
# [128] ns-plain-safe-out
# [129] ns-plain-safe-in
# [130] ns-plain-char(c)
my $PLAIN_WORD_OUT = qr{
    (?:[^\P{Graph}:\#]|[:](?=\p{Graph}))
    [^\P{Graph}:]*(?:[:]+[^\P{Graph}:]+)*
}msx;
my $PLAIN_WORD_IN = qr{
    (?:[^\P{Graph}:\#,\[\]\{\}]|[:](?=[^\P{Graph},\[\]\{\}]))
    [^\P{Graph}:,\[\]\{\}]*(?:[:]+[^\P{Graph}:,\[\]\{\}]+)*
}msx;

# [133] ns-plain-one-line(c)
my $PLAIN_ONE_OUT = qr{
    (?!(?:^---|^[.][.][.]))
    (?:[^\P{Graph}?:\-,\[\]\{\}\#&*!|>'"%\@`]|[?:\-](?=\p{Graph}))
    [^\P{Graph}:]*(?:[:]+[^\P{Graph}:]+)*
    (?:[ \t]+$PLAIN_WORD_OUT)*
}msx;
my $PLAIN_ONE_IN = qr{
    (?!(?:^---|^[.][.][.]))
    (?:[^\P{Graph}?:\-,\[\]\{\}\#&*!|>'"%\@`]|[?:\-](?=[^\P{Graph},\[\]\{\}]))
    [^\P{Graph}:,\[\]\{\}]*(?:[:]+[^\P{Graph}:,\[\]\{\}]+)*
    (?:[ \t]+$PLAIN_WORD_IN)*
}msx;

# [131] ns-plain(n,c)
sub ns_plain {
    my($derivs, $n, $c) = @_;
    $n >= 0 or Carp::confess("ns-plain(n,c): n >= 0, but $n.");
    my $lex = $c eq 'flow-in'
    ? qr{(
        $PLAIN_ONE_IN
        (?: [ \t]* \n (?:(?:[ ]{$n}[ \t]*|[ ]*)\n)*
            (?!(?:---|[.][.][.])) [ ]{$n}[ \t]*
            $PLAIN_WORD_IN(?:[ \t]+$PLAIN_WORD_IN)*)*
    )}msx
    : qr{(
        $PLAIN_ONE_OUT
        (?: [ \t]* \n (?:(?:[ ]{$n}[ \t]*|[ ]*)\n)*
            (?!(?:---|[.][.][.])) [ ]{$n}[ \t]*
            $PLAIN_WORD_OUT(?:[ \t]+$PLAIN_WORD_OUT)*)*
    )}msx;
    my($derivs1, $text) = match($derivs, $lex) or return;
    return ($derivs1, ['ns-plain',  decode_s_flow_folded($text)]);
}

sub decode_s_flow_folded {
    my($s) = @_;
    $s =~ s{[ \t]* \n ((?:[ \t]*\n)*) [ \t]*}
           { ("\n" x ((my $x = $1) =~ tr/\n/\n/)) || q( ) }egmsx;
    return $s;
}

# 7.4. Flow Collection Styles

my %JSON_FLOW_NODE = (
    'c-flow-sequence' => 'c-flow-sequence',
    'c-flow-mapping'  => 'c-flow-mapping',
    'c-single-quoted' => 'c-single-quoted',
    'c-double-quoted' => 'c-double-quoted',    
);

sub is_json_flow_node {
    my($node) = @_;
    return if ! $node;
    my $kind = $node->[0] eq 'c-ns-properties' ? $node->[3][0] : $node->[0];
    return $JSON_FLOW_NODE{$kind};
}

# [137] c-flow-sequence(n,c)
sub c_flow_sequence {
    my($derivs, $n, $c) = @_;
    my $c1 = 'flow-in';
    my $derivs1 = match($derivs, '[') or return;
    $derivs = s_separate($derivs1, $n, $c) || $derivs1;
    my @seq;
    while (my($derivs2, $x) = ns_flow_seq_entry($derivs, $n, $c1)) {
        push @seq, $x;
        $derivs = s_separate($derivs2, $n, $c1) || $derivs2;
        $derivs2 = match($derivs, ',') or last;
        $derivs = s_separate($derivs2, $n, $c1) || $derivs2;
    }
    $derivs = match($derivs, ']') or return;
    return ($derivs, ['c-flow-sequence', @seq]);
}

# [139] ns-flow-seq-entry
sub ns_flow_seq_entry {
    my($derivs, $n, $c) = @_;
    my($derivs1, $entry) = ns_flow_map_explicit_entry($derivs, $n, $c);
    return ($derivs1, ['c-flow-mapping', @{$entry}]) if $derivs1;

    my($derivs2, $key) = ns_flow_node($derivs, 0, 'flow-key');
    $key ||= ['e-scalar'];
    my $json_key = is_json_flow_node($key);
    my($derivs3, $value) =
        c_ns_flow_map_value($derivs2 || $derivs, $n, $c, $json_key);
    return ($derivs3, ['c-flow-mapping', $key, $value]) if $derivs3;

    return ($derivs2, $key) if $json_key;
    return ns_flow_node($derivs, $n, $c);
}

# [140] c-flow-mapping(n,c)
sub c_flow_mapping {
    my($derivs, $n, $c) = @_;
    my $c1 = 'flow-in';
    my $derivs1 = match($derivs, '{') or return;
    $derivs = s_separate($derivs1, $n, $c) || $derivs1;
    my @map;
    while (my($derivs2, $x) = ns_flow_map_entry($derivs, $n, $c1)) {
        push @map, @{$x};
        $derivs = s_separate($derivs2, $n, $c1) || $derivs2;
        $derivs2 = match($derivs, ',') or last;
        $derivs = s_separate($derivs2, $n, $c1) || $derivs2;
    }
    $derivs = match($derivs, '}') or return;
    return ($derivs, ['c-flow-mapping', @map]);
}

# [142] ns-flow-map-entry
sub ns_flow_map_entry {
    my($derivs, $n, $c) = @_;
    my($derivs1, $entry) = ns_flow_map_explicit_entry($derivs, $n, $c);
    return ($derivs1, $entry) if $derivs1;
    return ns_flow_map_implicit_entry($derivs, $n, $c);
}

# [143] ns-flow-map-explicit-entry(n,c)
sub ns_flow_map_explicit_entry {
    my($derivs, $n, $c) = @_;
    my $derivs1 = match($derivs, '?') or return;
    my $derivs2 = s_separate($derivs1, $n, $c) or return;
    my($derivs3, $entry) = ns_flow_map_implicit_entry($derivs2, $n, $c);
    return ($derivs3, $entry) if $derivs3;
    return ($derivs2, [['e-scalar'], ['e-scalar']]);
}

# [144] ns-flow-map-implicit-entry(n,c)
sub ns_flow_map_implicit_entry {
    my($derivs, $n, $c) = @_;
    my($derivs1, $key) = ns_flow_node($derivs, $n, $c);
    $key ||= ['e-scalar'];
    my $adjacent = is_json_flow_node($key);
    my($derivs2, $value) =
        c_ns_flow_map_value($derivs1 || $derivs, $n, $c, $adjacent);
    return ($derivs2, [$key, $value]) if $derivs2;
    return ($derivs1, [$key, ['e-scalar']]) if $derivs1;
    return;
}

# [147] s-separate(n,c)? c-ns-flow-map-separate-value(n,c)
# [149] s-separate(n,c)? c-ns-flow-map-adjacent-value(n,c)
sub c_ns_flow_map_value {
    my($derivs, $n, $c, $adjacent) = @_;
    my $colon = $adjacent ? q(:)
        : $c eq 'flow-in' ? qr/[:](?=[ \t\r\n,\[\]\{\}])/omsx
        : qr/[:](?=[ \t\r\n])/omsx;
    my $derivs1 = s_separate($derivs, $n, $c) || $derivs;
    my $derivs2 = match($derivs1, $colon) or return;
    RULE1: {
        my $derivs3 = s_separate($derivs2, $n, $c)
            || ($adjacent ? $derivs2 : last);
        my($derivs4, $value) = ns_flow_node($derivs3, $n, $c) or last;
        return ($derivs4, $value);
    }
    return ($derivs2, ['e-scalar']);
}

# [161] ns-flow-node(n,c)
sub ns_flow_node {
    my($derivs, $n, $c) = @_;
    my $c1 = $c eq 'flow-in' || $c eq 'flow-key' ? 'flow-in' : 'flow-out';
    my $key = "ns-flow-node($n,$c1)";
    my($derivs4, $node4) = memorize($derivs, $key, sub{
        my($derivs3, $node) = c_ns_alias_node($derivs);
        return [$derivs3, $node] if $derivs3;
        my($derivs1, $prop) = c_ns_properties($derivs, $n, $c1);
        my $derivs2 = $derivs1 ? s_separate($derivs1, $n, $c1) : $derivs;
        not $derivs2
        or ($derivs3, $node) = ns_plain($derivs2, $n, $c1)
        or ($derivs3, $node) = c_flow_sequence($derivs2, $n, $c1)
        or ($derivs3, $node) = c_flow_mapping($derivs2, $n, $c1)
        or ($derivs3, $node) = c_single_quoted($derivs2, $n, $c1)
        or ($derivs3, $node) = c_double_quoted($derivs2, $n, $c1);
        return [$derivs3, $prop ? [@{$prop}, $node] : $node] if $derivs3;
        return [$derivs1, [@{$prop}, ['e-scalar']]] if $derivs1;
        return;
    }) or return;
    if ($c eq 'block-key' || $c eq 'flow-key') {
        if (! $derivs->[2]{$derivs->[1]}{$key}[2]) {
            my $i = index ${$derivs->[0]}, "\n", $derivs->[1];
            $derivs->[2]{$derivs->[1]}{$key}[2] =
                $i >= 0 && $i < $derivs4->[1] ? 'n' : 'w';
        }
        return if $derivs->[2]{$derivs->[1]}{$key}[2] eq 'n';
    }
    return ($derivs4, $node4);
}

# 8.1. Block Scalar Styles
#
# combined into c-l+block-scalar(n)
# [170] c-l+literal(n)
# [174] c-l+folded(n)
my $BLOCK_SCALAR =
    qr/([|>])(?:([0-9])([+-]?)|([+-])([0-9])?)? $S_B_COMMENT/msx;

sub c_l__block_scalar {
    my($derivs, $n) = @_;
    my($derivs1, @capture) = match($derivs, $BLOCK_SCALAR) or return;
    my $type = $capture[0] eq q(|) ? 'c-l+literal' : 'c-l+folded';
    my $indentation = defined $capture[1] ? $capture[1] : $capture[4];
    my $chomp = $capture[2] || $capture[3] || q();
    if (! defined $indentation) {
        my(undef, $w) = match($derivs1, qr/(?:[ \t]*\n)*([ ]*)[^ \n]/omsx);
        $w ||= q();
        $indentation = (length $w) - $n; 
    }
    my $n1 = $n + $indentation;
    # A block scalar may consists only of empty lines.
    # see specification's 8.1.1.2. Block Chomping Indicator
    my $lex = $n1 <= $n
        ? qr/((?:[ \t]*\n)*)/msx
        : qr{(
            (?:[ ]*\n)*
            (?: (?!(?:^---|^[.][.][.]))[ ]{$n1}[\p{Graph} \t]+
                (?: \n
                    (?:(?!(?:^---|^[.][.][.]))[ ]{$n1}[\p{Graph} \t]+|[ ]*) )* )?
            (?:\n|\z) 
          )}msx;
    my($derivs2, $s) = match($derivs1, $lex) or return;
    my $derivs3 = s_l_comments($derivs2) || $derivs2;
    $n1 > 0 and $s =~ s/^[ ]{0,$n1}//gmsx;
    # b-chomped-last(t) and l-chomped-empty(n,t)
    my $b_chomped_last = q();
    my $l_chomped_empty = $s =~ s/(\n+)\z//msx ? $1 : q();
    if (length $s > 0 && length $l_chomped_empty > 0) {
        $b_chomped_last = $chomp eq q(-) ? q() : "\n";
        chop $l_chomped_empty;
    }
    my $l_chomped = 
          ! $chomp ? $b_chomped_last
        : $chomp eq q(+) ? $b_chomped_last . $l_chomped_empty
        : q();
    if ($type eq 'c-l+folded') {
        $s =~ s{^[ \t]*$}{}gmsx;
        $s =~ s{^([^ \t\n][^\n]*)\n(?=(\n*)[^ \t\n])}
               { $1 . ($2 ? q() : q( )) }egmsx;
    }
    return ($derivs3, [$type, $s . $l_chomped]);
}

# 8.2. Block Collection Styles
#
# [183] l+block-sequence(n)
sub l__block_sequence {
    my($derivs, $n) = @_;
    my @seq;
    my($derivs1, $spaces) =
        match($derivs, qr/([ ]*)(?=[-][ \t\n])/omsx) or return;
    my $n1 = length $spaces;
    $n1 > $n or return;
    my($derivs2, $seq) = l_block_seq_entries($derivs, $n1);
    return ($derivs2, ['l+block-sequence', @{$seq}]) if @{$seq};
    return;
}

# [186] ns-l-compact-sequence(n)
sub ns_l_compact_sequence {
    my($derivs, $n) = @_;
    my $derivs1 = match($derivs, qr/[-](?=[ \t\n])/omsx) or return;
    my($derivs2, $entry) =
        s_l__block_indented($derivs1, $n, 'block-in') or return;
    my($derivs3, $seq) = l_block_seq_entries($derivs2, $n);
    return ($derivs3, ['ns-l-compact-sequence', $entry, @{$seq}]);
}

sub l_block_seq_entries {
    my($derivs, $n) = @_;
    my @seq;
    my $lex = qr/[ ]{$n}-(?=[ \t\n])/msx;
    while (my $derivs1 = match($derivs, $lex)) {
        my($derivs2, $entry) =
            s_l__block_indented($derivs1, $n, 'block-in') or last;
        push @seq, $entry;
        $derivs = $derivs2;
    }
    return ($derivs, \@seq);
}

# [185] s-l-block-indented(n,c)
sub s_l__block_indented {
    my($derivs, $n, $c) = @_;
    RULE: {
        my($derivs1, $spaces) = match($derivs, qr/([ ]+)/omsx) or last;
        my $m = length $spaces;
        my($derivs2, $entry2) = ns_l_compact_sequence($derivs1, $n + 1 + $m);
        return ($derivs2, $entry2) if $derivs2;
        my($derivs3, $entry3) = ns_l_compact_mapping($derivs1, $n + 1 + $m);
        return ($derivs3, $entry3) if $derivs3;
    }
    RULE: {
        my($derivs1, $entry) = s_l__block_node($derivs, $n, $c);
        return ($derivs1, $entry) if $derivs1;
        my $derivs2 = s_l_comments($derivs) or last;
        return ($derivs2, ['e-scalar']);
    }
    return;
}

# [187] l+block-mapping(n)
sub l__block_mapping {
    my($derivs, $n) = @_;
    my($derivs1, $spaces) = match($derivs, qr/([ ]*)/omsx) or return;
    my $n1 = length $spaces;
    $n1 > $n or return;
    my($derivs2, $map) = l_block_map_entries($derivs, $n1);
    return ($derivs2, ['l+block-mapping', @{$map}]) if @{$map};
    return;
}

# [195] ns-l-compact-mapping(n)
sub ns_l_compact_mapping {
    my($derivs, $n) = @_;
    my($derivs1, $entry) = ns_l_block_map_entry($derivs, $n) or return;
    my($derivs2, $map) = l_block_map_entries($derivs1, $n);
    return ($derivs2, ['ns-l-compact-mapping', @{$entry}, @{$map}]);
}

sub l_block_map_entries {
    my($derivs, $n) = @_;
    my @map;
    my $indent = q( ) x $n;
    while (my $derivs1 = match($derivs, $indent)) {
        my($derivs2, $entry) = ns_l_block_map_entry($derivs1, $n) or last;
        push @map, @{$entry};
        $derivs = $derivs2;
    }
    return ($derivs, \@map);
}

# [188] ns-l-block-map-entry(n)
sub ns_l_block_map_entry {
    my($derivs, $n) = @_;
    RULE: {
        my $derivs1 = match($derivs, '?') or last;
        my($derivs2, $key) =
            s_l__block_indented($derivs1, $n, 'block-out') or last;
        my($derivs3, $value);
        $derivs2
        and $derivs3 = match($derivs2, qr/^[ ]{$n}:/msx)
        and ($derivs3, $value) = s_l__block_indented($derivs3, $n, 'block-out')
        and return ($derivs3, [$key, $value]);
        return ($derivs2, [$key, ['e-scalar']]);
    }
    RULE: {
        my($derivs1, $key) = ns_flow_node($derivs, 0, 'block-key');
        $key ||= ['e-scalar'];
        my $derivs2 = $derivs1 && match($derivs1, qr/[ ]+/omsx) || $derivs1;
        my $derivs3 = match($derivs2 || $derivs, ':') or last;
        my($derivs4, $value) = s_l__block_node($derivs3, $n, 'block-out');
        return ($derivs4, [$key, $value]) if $derivs4;
        my $derivs5 = s_l_comments($derivs3) or last;
        return ($derivs5, [$key, ['e-scalar']]);
    }
    return;
}

# [196] s-l+block-node(n,c)
sub s_l__block_node {
    my($derivs, $n, $c) = @_;
    RULE: {
        my $derivs1 = s_separate($derivs, $n + 1, $c) or last;
        my($derivs2, $prop) = c_ns_properties($derivs1, $n + 1, $c);
        my $derivs3 = $derivs2 && s_separate($derivs2, $n + 1, $c)
            || $derivs1;
        my($derivs4, $node) = c_l__block_scalar($derivs3, $n) or last;
        return ($derivs4, $prop ? [@{$prop}, $node] : $node);
    }
    RULE: {
        my($derivs1, $x, $prop, $derivs3, $node);
        $derivs
        and $derivs1 = s_separate($derivs, $n + 1, $c)
        and ($derivs1, $x) = c_ns_properties($derivs1, $n + 1, $c)
        and $derivs1 = s_l_comments($derivs1)
        and $prop = $x
        or  $derivs1 = s_l_comments($derivs) or last;
        my $n1 = $c eq 'block-out' ? $n - 1 : $n;
        $derivs1 and (
           ($derivs3, $node) = l__block_sequence($derivs1, $n1)
        or ($derivs3, $node) = l__block_mapping($derivs1, $n) ) or last;
        return ($derivs3, $prop ? [@{$prop}, $node] : $node);
    }
    RULE: {
        my $derivs1 = s_separate($derivs, $n + 1, 'flow-out') or last;
        my($derivs2, $node) =
            ns_flow_node($derivs1, $n + 1, 'flow-out') or last;
        my $derivs3 = s_l_comments($derivs2) or last;
        return ($derivs3, $node);
    }
    return;
}

# [205] l-document-suffix
my $L_DOCUMENT_SUFFIX = qr/(?:[.][.][.]$S_L_COMMENTS)+/msx;

# [211] l-yaml-stream
sub l_yaml_stream {
    my($derivs) = @_;
    my @stream;
    my $but_first = 0;
    my $derivs1 = $derivs;
    while (! end_of_file($derivs1)) {
        $derivs1 = match($derivs1, $L_COMMENT) || $derivs1;
        if ($but_first++) {
            my $derivs2 = match($derivs1, $L_DOCUMENT_SUFFIX) or last;
            $derivs1 = $derivs2;
        }
        end_of_file($derivs1) and last;
        my @directive;
        if (match($derivs1, '%')) {
            while (my($derivs2, $directive) = l_directive($derivs1)) {
                push @directive, $directive;
                $derivs1 = $derivs2;
            }
            match($derivs1, '---') or return;
        }
        if (! match($derivs1, '---')) {
            my($derivs2, $node) = s_l__block_node($derivs1, -1, 'block-in');
            if ($derivs2) {
                push @stream, ['l-bare-document', $node];
                $derivs1 = $derivs2;
            }
        }
        while (my $derivs2 = match($derivs1, '---')) {
            my($derivs3, $node) = s_l__block_node($derivs2, -1, 'block-in');
            if (! $node) {
                $derivs3 = s_l_comments($derivs2)
                    or croak 'SyntaxError: broken directives end marker.';
                $node = ['e-scalar'];
            }
            if (@directive) {
                push @stream, ['l-directive-document', @directive, $node];
                @directive = ();
            }
            else {
                push @stream, ['l-explicit-document', $node];
            }
            $derivs1 = match($derivs3, $L_COMMENT) || $derivs3;
        }
    }
    return ($derivs1, ['l-yaml-stream', @stream]);
}

1;

__END__

=pod

=head1 NAME

YAML::Parser::Btrack - Pure Perl YAML 1.2 Backtrack Parser

=head1 VERSION

0.011

=head1 SYNOPSIS

    use YAML::Parser::Btrack qw(derivs l_yaml_stream);
    use Data::Dumper;

    my $derivs = derivs(<<'EOS');
    %YAML 1.2
    ---
    - - a
      - b
    -
      C : c
    EOS
    my($derivs1, $parsing_tree) = YAML::Parser::Btrack::l_yaml_stream($derivs);
    print Data::Dumper->new([$parsing_tree])->Terse(1)->Useqq(1)->Indent(1)->Dump;

=head1 DESCRIPTION

=head1 FUNCTIONS 

=over

=item C<< derivs($string) >>
=item C<< derivs(\$string) >>

Creates derivs arrayref for parsing. 
The parameter string may also be a scalar reference.

=item C<< derivs($derivs, $pos) >>

Copy a derivs arrayref and set new position.

=item C<< match($derivs, $phrase) >>

Returns next positioned $derivs and captured strings when it matchs $phrase.
$phrase is a $substr or a regexp.

=item C<< end_of_file($derivs) >>

Returns $derivs when it is at end of file.

=item C<< memorize($derivs, $key, \&yield) >>

=item C<< s_separate_in_line($derivs) >>

The production s-separate-in-line.

=item C<< s_flow_line_prefix($derivs, $n) >>

The production s-flow-line-prefix.

=item C<< s_b_comment >>

The production s-b-comment.
Regexp pattern $S_B_COMMENT is used from other productions.
This function is a stub to test the regexp.

=item C<< s_l_comments >>

The production s-l-comments.
This corresponds to line break in the YAML document.

=item C<< s_separate >>

The production s-separate.
This corresponds to white spaces in the YAML document.

=item C<< l_directive >>

The production l-directive included s-l-comments.

    %YAML 1.2  # comment
    %TAG !yaml! tag:yaml.org,2002:
    %FOO foo bar baz

to

    ['ns-yaml-directive', 'YAML', '1.2']
    ['ns-tag-directive', 'TAG', '!yaml!', 'tag:yaml.org,2002:']
    ['ns-reserved-directive', 'FOO', 'foo', 'bar', 'baz']

=item C<< c_ns_properties >>

The production c-ns-properties produces a tag property
and/or an anchor property.

    !!str &anchor

to

    ['c-ns-properties',
        ['c-ns-tag-property', '!!str'],
        ['c-ns-anchor-property', '&anchor'] ]

=item C<< c_ns_tag_property >>

The production c-ns-tag-property part of c-ns-properties.

=item C<< c_ns_anchor_property >>

The production c-ns-anchor-property part of c-ns-properties.

=item C<< c_ns_alias_node >>

The production c-ns-alias-node.

    *anchor

to

    ['c-ns-alias-node', '*anchor']

=item C<< c_double_quoted >>

The production c-double-quoted.
The texts are unescaped and are folded.

    "string"

to

    ['c-double-quoted', 'string']

=item C<< decode_double_text >>

Decodes given double text.
Unescapes back slashed characters and back slased line feeds.
Folds lines as flow styles folding as the production s-flow-folded.

=item C<< c_single_quoted >>

The production c-single-quoted.
The texts are folded.

    'string'

to

    ['c-single-quoted', 'string']

=item C<< decode_single_text >>

Decodes given single text.
Unescapes single-quote single-quote pairs.
Folds lines as flow styles folding as the production s-flow-folded.

=item C<< ns_plain >>

The production ns-plain.
The texts are folded.

    plain text

to

    ['ns-plain', 'plain text']

=item C<< decode_s_flow_folded >>

Folds lines as flow styles folding as the production s-flow-folded.

=item C<< c_flow_sequence >>

The production c-flow-sequence and ns-s-flow-seq-entries.

    [ one, two ]

to

    ['c-flow-sequence',
        ['ns-plain', 'one'],
        ['ns-plain', 'two']]

ns-s-flow-seq-entries's last separate characters are optional.

    [ one, two, ] # same as [ one, two ]

=item C<< ns_flow_seq_entry >>

The production ns-flow-seq-entry part of c-flow-sequence.

=item C<< c_flow_mapping >>

The production c-flow-mapping and ns-s-flow-map-entries.

    { one : two, three : four }

to

    ['c-flow-mapping',
        ['ns-plain', 'one'], ['ns-plain', 'two'],
        ['ns-plain', 'three'], ['ns-plain', 'four']]

ns-s-flow-map-entries's last separate characters are optional.

    { one : two, three : four, } # same as { one: two, three: four }

=item C<< ns_flow_map_entry >>

The production ns-flow-map-entry part of c-flow-mapping.

=item C<< ns_flow_map_explicit_entry >>

The production ns-flow-map-explicit-entry part of ns-flow-map-entry.
Treats

    { ? explicit key : explicit value }

=item C<< ns_flow_map_implicit_entry >>

The production ns-flow-map-implicit-entry part of ns-flow-map-entry.
Treats

    { implicit key : implicit value }

=item C<< ns_flow_node >>

The production ns-flow-node.
Treats

    *alias
    plain text
    "double quoted"
    'single quoted'
    [flow, sequence]
    {flow : mapping}
    !!str   # tagged empty scalar
    !!str tagged plain text
    !!str tagged "double quoted"
    !!str tagged 'single quoted'
    !!seq [tagged, flow, sequence]
    !!map {tagged : flow mapping}

=item C<< c_l__block_scalar >>

The production c-l+literal and c-l+folded.
On c-l+folded, folds lines as block styles folding.

    |
      literal
      text

to

    ['c-l+literal', qq(literal\ntext\n)]

or

    >
      folded
      text

to

    ['c-l+folded', qq(folded text\n)]

=item C<< l__block_sequence >>

The production l+block-sequence.

    -
      block
    - sequence
    - entry
    - - compact
      - sequence
    - compact implicit: mapping
    - ? compact explicit
      : mapping

to

    ['l+block-sequence',
        ['ns-plain', 'block'],
        ['ns-plain', 'sequence'],
        ['ns-plain', 'entry'],
        ['ns-l-compact-sequence',
            ['ns-plain', 'compact'],
            ['ns-plain', 'sequence']],
        ['ns-l-compact-mapping',
            ['ns-plain', 'compact implicit'],
            ['ns-plain', 'mapping']],
        ['ns-l-compact-mapping',
            ['ns-plain', 'compact explicit'],
            ['ns-plain', 'mapping'] ]]

=item C<< ns_l_compact_sequence >>

The production ns-l-compact-sequence part of s-l+block-indented.

=item C<< l_block_seq_entries >>

The part of l+block-sequence and ns-l-compact-sequence.

=item C<< s_l__block_indented >>

The production s-l+block-indented
part of l+block-sequence and l+block-mapping.

=item C<< l__block_mapping >>

The production l+block-mapping.

    ? explicit key
    : explicit value
    implicit key: implicit value
    ? - compact
    : - sequence

to

    ['l+block-mapping',
        ['ns-plain', 'explicit key'],
        ['ns-plain', 'explicit value'],
        ['ns-plain', 'implicit key'], ['ns-plain', 'implicit value'],
        ['ns-l-compact-sequence',
            ['ns-plain', 'compact']],
        ['ns-l-compact-sequence',
            ['ns-plain', 'sequence']]]

=item C<< ns_l_block_map_entry >>

The production ns-l-block-map-entry part of l+block-mapping.

=item C<< ns_l_compact_mapping >>

The production ns-l-compact-mapping part of s-l+block-indented.

=item C<< l_block_map_entries >>

The part of l+block-mapping and ns-l-compact-mapping.

=item C<< s_l__block_node >>

The production s-l+block-node.

    |
      literal
    >
      folded
    - sequence
    ? explicit
    : mapping
    implicit: mapping
    *flow-anchor
    flow plain text
    "flow double quoted"
    'flow single quoted'
    [ flow, sequence ]
    { ? flow : mapping }
    !!tag |
      literal
    !!tag >
      folded
    !!seq
    - sequence
    !!map
    ? explicit
    : mapping
    !!map
    implicit: mapping
    !!str flow plain text
    !!str "flow double quoted"
    !!str 'flow single quoted'
    !!seq [ flow, sequence ]
    !!map { ? flow : mapping }
    !!null   # empty flow scalar 

=item C<< l_yaml_stream >>

The production l-yaml-stream.

    bare document
    ...
    %YAML 1.2
    --- >
      directive document
    --- 'explicit document'
    ---
    explicit document
    ...
    bare document
    ...
    %YAML 1.2
    ---
    directive document

to

    ['l-yaml-stream',
        ['l-bare-document',
            ['ns-plain', 'bare document']],
        ['l-directive-document',
            ['ns-yaml-directive', 'YAML', '1.2'],
            ['c-l+folded', qq(directive document\n)]],
        ['l-explicit-document',
            ['c-single-quoted', 'explicit document']],
        ['l-explicit-document',
            ['ns-plain', 'explicit document']],
        ['l-bare-document',
            ['ns-plain', 'bare document']],
        ['l-directive-document',
            ['ns-yaml-directive', 'YAML', '1.2'],
            ['ns-plain', qq(directive document)]] ]

=back

=head1 DEPENDENCIES

None.

=head1 SEE ALSO

L<http://www.yaml.org/spec/1.2/spec.html>

=head1 LIMITATIONS

Buggy and tests are insufficient.

=head1 AUTHOR

MIZUTANI Tociyuki  C<< <tociyuki@gmail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
