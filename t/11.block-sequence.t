use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 5;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*l__block_sequence = \&YAML::Parser::Btrack::l__block_sequence;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Block Sequenct';

    it 'should match flat sequence.';

        my $s1 = derivs(
              qq(-\n)
            . qq(  a\n)
            . qq(-\n)
            . qq(  b\n)
            . qq(---\n),
        );
        my $s1end = match($s1,
              qq(-\n)
            . qq(  a\n)
            . qq(-\n)
            . qq(  b\n),
        );
        is_deeply [strip l__block_sequence($s1, -1, 'block-in')],
            [
                strip $s1end,
                ['l+block-sequence',
                    ['ns-plain', 'a'],
                    ['ns-plain', 'b'], ],
            ], spec;

    it 'should match flat sequence again.';

        my $s2 = derivs(
              qq(- a\n)
            . qq(- b\n)
            . qq(---\n),
        );
        my $s2end = match($s2,
              qq(- a\n)
            . qq(- b\n),
        );
        is_deeply [strip l__block_sequence($s2, -1, 'block-in')],
            [
                strip $s2end,
                ['l+block-sequence',
                    ['ns-plain', 'a'],
                    ['ns-plain', 'b'], ],
            ], spec;

    it 'should match nested sequence.';

        my $s3 = derivs(
              qq(-\n)
            . qq(  - a0\n)
            . qq(  - a1\n)
            . qq(-\n)
            . qq(  - b0\n)
            . qq(-\n)
            . qq(  c\n)
            . qq(---\n),
        );
        my $s3end = match($s3,
              qq(-\n)
            . qq(  - a0\n)
            . qq(  - a1\n)
            . qq(-\n)
            . qq(  - b0\n)
            . qq(-\n)
            . qq(  c\n),
        );
        is_deeply [strip l__block_sequence($s3, -1, 'block-in')],
            [
                strip $s3end,
                ['l+block-sequence',
                    ['l+block-sequence',
                        ['ns-plain', 'a0'],
                        ['ns-plain', 'a1'], ],
                    ['l+block-sequence',
                        ['ns-plain', 'b0'], ],
                    ['ns-plain', 'c'], ],
            ], spec;

    it 'should match compact sequence.';

        my $s4 = derivs(
              qq(- - a0\n)
            . qq(  - a1\n)
            . qq(- - b0\n)
            . qq(- c\n)
            . qq(---\n),
        );
        my $s4end = match($s4,
              qq(- - a0\n)
            . qq(  - a1\n)
            . qq(- - b0\n)
            . qq(- c\n)
        );
        is_deeply [strip l__block_sequence($s4, -1, 'block-in')],
            [
                strip $s4end,
                ['l+block-sequence',
                    ['ns-l-compact-sequence',
                        ['ns-plain', 'a0'],
                        ['ns-plain', 'a1'], ],
                    ['ns-l-compact-sequence',
                        ['ns-plain', 'b0'], ],
                    ['ns-plain', 'c'], ],
            ], spec;

    it 'should match example 8.15.';

        my $s5 = derivs(
              qq(-   # Empty\n)
            . qq(- |\n)
            . qq( block node\n)
            . qq(- - one # Compact\n)
            . qq(  - two # sequence\n)
            . qq(# - one: two # Compact mapping\n) # test with 12.block-mapping.t later
            . qq(---\n),
        );
        my $s5end = match($s5,
              qq(-   # Empty\n)
            . qq(- |\n)
            . qq( block node\n)
            . qq(- - one # Compact\n)
            . qq(  - two # sequence\n)
            . qq(# - one: two # Compact mapping\n)
        );
        is_deeply [strip l__block_sequence($s5, -1, 'block-in')],
            [
                strip $s5end,
                ['l+block-sequence',
                    ['e-scalar'],
                    ['c-l+literal', qq(block node\n)],
                    ['ns-l-compact-sequence',
                        ['ns-plain', 'one'],
                        ['ns-plain', 'two'], ], ],
            ], spec;
}

