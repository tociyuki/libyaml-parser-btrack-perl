use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 9;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*ns_flow_node = \&YAML::Parser::Btrack::ns_flow_node;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Flow Nodes';

    it 'should match flow sequence.';

        my $f1 = derivs(qq([ a, b ]\n));
        my $f1end = match($f1, qq([ a, b ]));

        is_deeply [strip ns_flow_node($f1, 0, 'flow-out')],
            [
                strip $f1end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'], ['ns-plain', 'b'], ],
            ], spec;

    it 'should match flow mapping.';

        my $f2 = derivs(qq({ a: b }\n));
        my $f2end = match($f2, qq({ a: b }));

        is_deeply [strip ns_flow_node($f2, 0, 'flow-out')],
            [
                strip $f2end,
                ['c-flow-mapping',
                    ['ns-plain', 'a'], ['ns-plain', 'b'], ],
            ], spec;

    it 'should match double quoted.';

        my $f3 = derivs(qq("a"\n));
        my $f3end = match($f3, qq("a"));

        is_deeply [strip ns_flow_node($f3, 0, 'flow-out')],
            [
                strip $f3end,
                ['c-double-quoted', 'a'],
            ], spec;

    it 'should match single quoted.';

        my $f4 = derivs(qq('b'\n));
        my $f4end = match($f4, qq('b'));

        is_deeply [strip ns_flow_node($f4, 0, 'flow-out')],
            [
                strip $f4end,
                ['c-single-quoted', 'b'],
            ], spec;

    it 'should match plain.';

        my $f5 = derivs(qq(c\n));
        my $f5end = match($f5, qq(c));

        is_deeply [strip ns_flow_node($f5, 0, 'flow-out')],
            [
                strip $f5end,
                ['ns-plain', 'c'],
            ], spec;

    it 'should match tagged double quoted.';

        my $f6 = derivs(qq(!!str "a"\n));
        my $f6end = match($f6, qq(!!str "a"));

        is_deeply [strip ns_flow_node($f6, 0, 'flow-out')],
            [
                strip $f6end,
                ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                    ['c-double-quoted', 'a'], ],
            ], spec;

    it 'should match anchored double quoted.';

        my $f7 = derivs(qq(&anchor "c"\n));
        my $f7end = match($f7, qq(&anchor "c"));

        is_deeply [strip ns_flow_node($f7, 0, 'flow-out')],
            [
                strip $f7end,
                ['c-ns-properties', undef, ['c-ns-anchor-property', '&anchor'],
                    ['c-double-quoted', 'c'], ],
            ], spec;

    it 'should match alias.';

        my $f8 = derivs(qq(*anchor\n));
        my $f8end = match($f8, qq(*anchor));

        is_deeply [strip ns_flow_node($f8, 0, 'flow-out')],
            [
                strip $f8end,
                ['c-ns-alias-node', '*anchor'],
            ], spec;

    it 'should match tagged empty scalar.';

        my $f9 = derivs(qq(!!str,\n));
        my $f9end = match($f9, qq(!!str));

        is_deeply [strip ns_flow_node($f9, 0, 'flow-out')],
            [
                strip $f9end,
                ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                    ['e-scalar'], ],
            ], spec;
}

