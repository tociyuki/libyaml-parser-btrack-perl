use strict;
use warnings;
use Carp;
use Test::More;
use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 26;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*c_flow_sequence = \&YAML::Parser::Btrack::c_flow_sequence ;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Flow Sequence';

    it 'should match [].';

        my $seq1 = derivs(qq([]\n));
        my $seq1end = match($seq1, qq([]));
        is_deeply [strip c_flow_sequence($seq1, 1, 'flow-in')],
            [strip $seq1end, ['c-flow-sequence']], spec;

    it 'should match [a].';

        my $seq2 = derivs(qq([a]\n));
        my $seq2end = match($seq2, qq([a]));
        is_deeply [strip c_flow_sequence($seq2, 1, 'flow-in')],
            [
                strip $seq2end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],],
            ], spec;

    it 'should match [ a].';

        my $seq3 = derivs(qq([ a]\n));
        my $seq3end = match($seq3, qq([ a]));
        is_deeply [strip c_flow_sequence($seq3, 1, 'flow-in')],
            [
                strip $seq3end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],],
            ], spec;

    it 'should match [a ].';

        my $seq4 = derivs(qq([a ]\n));
        my $seq4end = match($seq4, qq([a ]));
        is_deeply [strip c_flow_sequence($seq4, 1, 'flow-in')],
            [
                strip $seq4end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],],
            ], spec;

    it 'should match [a,].';

        my $seq5 = derivs(qq([a,]\n));
        my $seq5end = match($seq5, qq([a,]));
        is_deeply [strip c_flow_sequence($seq5, 1, 'flow-in')],
            [
                strip $seq5end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],],
            ], spec;

    it 'should match [a ,].';

        my $seq6 = derivs(qq([a ,]\n));
        my $seq6end = match($seq6, qq([a ,]));
        is_deeply [strip c_flow_sequence($seq6, 1, 'flow-in')],
            [
                strip $seq6end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],],
            ], spec;

    it 'should match [a, ].';

        my $seq7 = derivs(qq([a, ]\n));
        my $seq7end = match($seq7, qq([a, ]));
        is_deeply [strip c_flow_sequence($seq7, 1, 'flow-in')],
            [
                strip $seq7end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],],
            ], spec;

    it 'should match [a,b].';

        my $seq8 = derivs(qq([a,b]\n));
        my $seq8end = match($seq8, qq([a,b]));
        is_deeply [strip c_flow_sequence($seq8, 1, 'flow-in')],
            [
                strip $seq8end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'], ['ns-plain', 'b'],],
            ], spec;

    it 'should match [a, b].';

        my $seq9 = derivs(qq([a, b]\n));
        my $seq9end = match($seq9, qq([a, b]));
        is_deeply [strip c_flow_sequence($seq9, 1, 'flow-in')],
            [
                strip $seq9end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'], ['ns-plain', 'b'],],
            ], spec;

    it 'should match [a,b ].';

        my $seq10 = derivs(qq([a,b ]\n));
        my $seq10end = match($seq10, qq([a,b ]));
        is_deeply [strip c_flow_sequence($seq10, 1, 'flow-in')],
            [
                strip $seq10end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'], ['ns-plain', 'b'],],
            ], spec;

    it 'should match [a, b,].';

        my $seq11 = derivs(qq([a, b,]\n));
        my $seq11end = match($seq11, qq([a, b,]));
        is_deeply [strip c_flow_sequence($seq11, 1, 'flow-in')],
            [
                strip $seq11end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'], ['ns-plain', 'b'],],
            ], spec;

    it 'should match [a, b, c, d, e].';

        my $seq12 = derivs(qq([a, b, c, d, e]\n));
        my $seq12end = match($seq12, qq([a, b, c, d, e]));
        is_deeply [strip c_flow_sequence($seq12, 1, 'flow-in')],
            [
                strip $seq12end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],
                    ['ns-plain', 'b'],
                    ['ns-plain', 'c'],
                    ['ns-plain', 'd'],
                    ['ns-plain', 'e'],
                ],
            ], spec;

    it 'should match [a, b, c, d, e,].';

        my $seq13 = derivs(qq([a, b, c, d, e,]\n));
        my $seq13end = match($seq13, qq([a, b, c, d, e,]));
        is_deeply [strip c_flow_sequence($seq13, 1, 'flow-in')],
            [
                strip $seq13end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],
                    ['ns-plain', 'b'],
                    ['ns-plain', 'c'],
                    ['ns-plain', 'd'],
                    ['ns-plain', 'e'],
                ],
            ], spec;

    it 'should match comments.';

        my $seq14 = derivs(
              qq([ # comment\n)
            . qq(  a  # comment\n)
            . qq(  ,  # comment\n\n)
            . qq(  b, # comment\n)
            . qq( ]\n),
        );
        my $seq14end = match($seq14,
              qq([ # comment\n)
            . qq(  a  # comment\n)
            . qq(  ,  # comment\n\n)
            . qq(  b, # comment\n)
            . qq( ]),
        );
        is_deeply [strip c_flow_sequence($seq14, 1, 'flow-in')],
            [
                strip $seq14end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'], ['ns-plain', 'b'],],
            ], spec;

    it 'should not match [,]';
 
        my $seq15 = derivs(qq([,]));
        is_deeply [c_flow_sequence($seq15, 1, 'flow-in')], [], spec;

    it 'should not match [,a]';
 
        my $seq16 = derivs(qq([,a]));
        is_deeply [c_flow_sequence($seq16, 1, 'flow-in')], [], spec;

    it 'should not match [a,,]';
 
        my $seq17 = derivs(qq([a,,]));
        is_deeply [c_flow_sequence($seq17, 1, 'flow-in')], [], spec;

    it 'should not match [a,,b]';
 
        my $seq18 = derivs(qq([a,,b]));
        is_deeply [c_flow_sequence($seq18, 1, 'flow-in')], [], spec;

    it 'should not match [a,b,,]';
 
        my $seq19 = derivs(qq([a,b,,]));
        is_deeply [c_flow_sequence($seq19, 1, 'flow-in')], [], spec;

    it 'should not match [a,b,,c]';
 
        my $seq20 = derivs(qq([a,b,,c]));
        is_deeply [c_flow_sequence($seq20, 1, 'flow-in')], [], spec;

    it 'should not match [a,b,,c,]';
 
        my $seq21 = derivs(qq([a,b,,c,]));
        is_deeply [c_flow_sequence($seq21, 1, 'flow-in')], [], spec;

    it 'should match [alias]';

        my $seq22 = derivs(qq([*a]));
        my $seq22end = match($seq22, qq([*a]));
        is_deeply [strip c_flow_sequence($seq22, 1, 'flow-in')],
            [
                strip $seq22end,
                ['c-flow-sequence',
                    ['c-ns-alias-node', '*a'],],
            ], spec;

    it 'should match [single]';

        my $seq23 = derivs(qq(['a']));
        my $seq23end = match($seq23, qq(['a']));
        is_deeply [strip c_flow_sequence($seq23, 1, 'flow-in')],
            [
                strip $seq23end,
                ['c-flow-sequence',
                    ['c-single-quoted', 'a'],],
            ], spec;

    it 'should match [double]';

        my $seq24 = derivs(qq(["a"]));
        my $seq24end = match($seq24, qq(["a"]));
        is_deeply [strip c_flow_sequence($seq24, 1, 'flow-in')],
            [
                strip $seq24end,
                ['c-flow-sequence',
                    ['c-double-quoted', 'a'],],
            ], spec;

    it 'should match [[]]';

        my $seq25 = derivs(qq([[]]));
        my $seq25end = match($seq25, qq([[]]));
        is_deeply [strip c_flow_sequence($seq25, 1, 'flow-in')],
            [
                strip $seq25end,
                ['c-flow-sequence',
                    ['c-flow-sequence'],],
            ], spec;

    it 'should match [a,[b,c],d]';

        my $seq26 = derivs(qq([a,[b,c],d]));
        my $seq26end = match($seq26, qq([a,[b,c],d]));
        is_deeply [strip c_flow_sequence($seq26, 1, 'flow-in')],
            [
                strip $seq26end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],
                    ['c-flow-sequence', ['ns-plain', 'b'], ['ns-plain', 'c']],
                    ['ns-plain', 'd'],
                ],
            ], spec;
}

