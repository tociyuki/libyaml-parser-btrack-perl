use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 12;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*l__block_mapping = \&YAML::Parser::Btrack::l__block_mapping;
*l__block_sequence = \&YAML::Parser::Btrack::l__block_sequence;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Block Mapping';

    it 'should match explicit flat mapping.';

        my $s1 = derivs(
              qq(?\n)
            . qq(  k0\n)
            . qq(:\n)
            . qq(  v0\n)
            . qq(?\n)
            . qq(  k1\n)
            . qq(:\n)
            . qq(  v1\n)
            . qq(---\n),
        );
        my $s1end = match($s1,
              qq(?\n)
            . qq(  k0\n)
            . qq(:\n)
            . qq(  v0\n)
            . qq(?\n)
            . qq(  k1\n)
            . qq(:\n)
            . qq(  v1\n)
        );
        is_deeply [strip l__block_mapping($s1, -1, 'block-in')],
            [
                strip $s1end,
                ['l+block-mapping',
                    ['ns-plain', 'k0'],
                    ['ns-plain', 'v0'],
                    ['ns-plain', 'k1'],
                    ['ns-plain', 'v1'], ],
            ], spec;

    it 'should match explicit flat mapping also.';

        my $s2 = derivs(
              qq(? k0\n)
            . qq(: v0\n)
            . qq(? k1\n)
            . qq(: v1\n)
            . qq(---\n),
        );
        my $s2end = match($s2,
              qq(? k0\n)
            . qq(: v0\n)
            . qq(? k1\n)
            . qq(: v1\n)
        );
        is_deeply [strip l__block_mapping($s2, -1, 'block-in')],
            [
                strip $s2end,
                ['l+block-mapping',
                    ['ns-plain', 'k0'],
                    ['ns-plain', 'v0'],
                    ['ns-plain', 'k1'],
                    ['ns-plain', 'v1'], ],
            ], spec;

    it 'should match explicit nested mapping.';

        my $s3 = derivs(
              qq(?\n)
            . qq(  ? k0k\n)
            . qq(  : k0v\n)
            . qq(:\n)
            . qq(  ? v0k\n)
            . qq(  : v0v\n)
            . qq(?\n)
            . qq(  k1\n)
            . qq(:\n)
            . qq(  v1\n)
            . qq(---\n),
        );
        my $s3end = match($s3,
              qq(?\n)
            . qq(  ? k0k\n)
            . qq(  : k0v\n)
            . qq(:\n)
            . qq(  ? v0k\n)
            . qq(  : v0v\n)
            . qq(?\n)
            . qq(  k1\n)
            . qq(:\n)
            . qq(  v1\n)
        );
        is_deeply [strip l__block_mapping($s3, -1, 'block-in')],
            [
                strip $s3end,
                ['l+block-mapping',
                    ['l+block-mapping',
                        ['ns-plain', 'k0k'],
                        ['ns-plain', 'k0v'], ],
                    ['l+block-mapping',
                        ['ns-plain', 'v0k'],
                        ['ns-plain', 'v0v'], ],
                    ['ns-plain', 'k1'],
                    ['ns-plain', 'v1'], ],
            ], spec;

    it 'should match implicit flat mapping.';

        my $s4 = derivs(
              qq(k0 :\n)
            . qq(  v0\n)
            . qq(k1: v1\n)
            . qq(---\n),
        );
        my $s4end = match($s4,
              qq(k0 :\n)
            . qq(  v0\n)
            . qq(k1: v1\n),
        );
        is_deeply [strip l__block_mapping($s4, -1, 'block-in')],
            [
                strip $s4end,
                ['l+block-mapping',
                    ['ns-plain', 'k0'],
                    ['ns-plain', 'v0'],
                    ['ns-plain', 'k1'], ['ns-plain', 'v1'], ],
            ], spec;

    it 'should match implicit nested mapping.';

        my $s5 = derivs(
              qq(k0:\n)
            . qq(  k01: v01\n)
            . qq(  k02:\n)
            . qq(    v02\n)
            . qq(k1 : v1\n)
            . qq(---\n),
        );
        my $s5end = match($s5,
              qq(k0:\n)
            . qq(  k01: v01\n)
            . qq(  k02:\n)
            . qq(    v02\n)
            . qq(k1 : v1\n)
        );
        is_deeply [strip l__block_mapping($s5, -1, 'block-in')],
            [
                strip $s5end,
                ['l+block-mapping',
                    ['ns-plain', 'k0'],
                    ['l+block-mapping',
                        ['ns-plain', 'k01'], ['ns-plain', 'v01'],
                        ['ns-plain', 'k02'],
                        ['ns-plain', 'v02'], ],
                    ['ns-plain', 'k1'], ['ns-plain', 'v1'], ],
            ], spec;

    it 'should match mix explicit and implicit entry.';

        my $s6 = derivs(
              qq(? k0\n)
            . qq(:\n)
            . qq(  k01: v01\n)
            . qq(  ? k02\n)
            . qq(  : v02\n)
            . qq(k1 : v1\n)
            . qq(---\n),
        );
        my $s6end = match($s6,
              qq(? k0\n)
            . qq(:\n)
            . qq(  k01: v01\n)
            . qq(  ? k02\n)
            . qq(  : v02\n)
            . qq(k1 : v1\n)
        );

        is_deeply [strip l__block_mapping($s6, -1, 'block-in')],
            [
                strip $s6end,
                ['l+block-mapping',
                    ['ns-plain', 'k0'],
                    ['l+block-mapping',
                        ['ns-plain', 'k01'], ['ns-plain', 'v01'],
                        ['ns-plain', 'k02'],
                        ['ns-plain', 'v02'], ],
                    ['ns-plain', 'k1'], ['ns-plain', 'v1'], ],
            ], spec;

    it 'should match examle 8.16.';

        my $s7 = derivs(
              qq(block mapping:\n)
            . qq( key: value\n)
            . qq(---\n),
        );
        my $s7end = match($s7,
              qq(block mapping:\n)
            . qq( key: value\n)
        );

        is_deeply [strip l__block_mapping($s7, -1, 'block-in')],
            [
                strip $s7end,
                ['l+block-mapping',
                    ['ns-plain', qq(block mapping)],
                    ['l+block-mapping',
                        ['ns-plain', 'key'], ['ns-plain', 'value'], ], ],
            ], spec;

    it 'should match example 8.17.';

        my $s8 = derivs(
              qq(? explicit key # Empty value\n)
            . qq(? |\n)
            . qq(  block key\n)
            . qq(: - one # Explicit compact\n)
            . qq(  - two # block value\n)
            . qq(---\n),
        );
        my $s8end = match($s8,
              qq(? explicit key # Empty value\n)
            . qq(? |\n)
            . qq(  block key\n)
            . qq(: - one # Explicit compact\n)
            . qq(  - two # block value\n),
        );

        is_deeply [strip l__block_mapping($s8, -1, 'block-in')],
            [
                strip $s8end,
                ['l+block-mapping',
                    ['ns-plain', 'explicit key'],
                    ['e-scalar'],
                    ['c-l+literal', qq(block key\n)],
                    ['ns-l-compact-sequence',
                        ['ns-plain', 'one'],
                        ['ns-plain', 'two'], ], ],
            ], spec;

    it 'should match compact mapping in example 8.15.';

        my $s9 = derivs(
              qq(-   # Empty\n)
            . qq(- |\n)
            . qq( block node\n)
            . qq(- - one # Compact\n)
            . qq(  - two # sequence\n)
            . qq(- one: two # Compact mapping\n)
            . qq(---\n),
        );
        my $s9end = match($s9,
              qq(-   # Empty\n)
            . qq(- |\n)
            . qq( block node\n)
            . qq(- - one # Compact\n)
            . qq(  - two # sequence\n)
            . qq(- one: two # Compact mapping\n)
        );

        is_deeply [strip l__block_sequence($s9, -1, 'block-in')],
            [
                strip $s9end,
                ['l+block-sequence',
                    ['e-scalar'],
                    ['c-l+literal', qq(block node\n)],
                    ['ns-l-compact-sequence',
                        ['ns-plain', 'one'],
                        ['ns-plain', 'two'], ],
                    ['ns-l-compact-mapping',
                        ['ns-plain', 'one'], ['ns-plain', 'two'], ], ],
            ], spec;

    it 'should match example 8.18.';

        my $s10 = derivs(
              qq(plain key: in-line value\n)
            . qq(:     # Boty empty\n)
            . qq("quoted key":\n)
            . qq(- entry\n)
            . qq(---\n),
        );
        my $s10end = match($s10,
              qq(plain key: in-line value\n)
            . qq(:     # Boty empty\n)
            . qq("quoted key":\n)
            . qq(- entry\n),
        );

        is_deeply [strip l__block_mapping($s10, -1, 'block-in')],
            [
                strip $s10end,
                ['l+block-mapping',
                    ['ns-plain', 'plain key'], ['ns-plain', 'in-line value'],
                    ['e-scalar'], ['e-scalar'],
                    ['c-double-quoted', 'quoted key'],
                    ['l+block-sequence',
                        ['ns-plain', 'entry'], ], ],
            ], spec;

    it 'should match example 8.19.';

        my $s11 = derivs(
              qq(- sun: yellow\n)
            . qq(- ? earth: blue\n)
            . qq(  : moon: white\n)
            . qq(---\n),
        );
        my $s11end = match($s11,
              qq(- sun: yellow\n)
            . qq(- ? earth: blue\n)
            . qq(  : moon: white\n),
        );

        is_deeply [strip l__block_sequence($s11, -1, 'block-in')],
            [
                strip $s11end,
                ['l+block-sequence',
                    ['ns-l-compact-mapping',
                        ['ns-plain', 'sun'], ['ns-plain', 'yellow'], ],
                    ['ns-l-compact-mapping',
                        ['ns-l-compact-mapping',
                            ['ns-plain', 'earth'], ['ns-plain', 'blue'], ],
                        ['ns-l-compact-mapping',
                            ['ns-plain', 'moon'], ['ns-plain', 'white'], ], ], ],
            ], spec;
}

{
    describe 'Block Implicit Key';

    it 'should allow backtracking to multi-lines plain on fails.';

        my $s1 = derivs(
              qq(- not compact implicit key\n)
            . qq(  but multi-lines\n)
            . qq(  plain text. \n)
            . qq(-\n)
            . qq(  not block implicit key\n)
            . qq(  but multi-lines\n)
            . qq(  plain text. \n)
            . qq(---\n),
        );
        my $s1end = match($s1,
              qq(- not compact implicit key\n)
            . qq(  but multi-lines\n)
            . qq(  plain text. \n)
            . qq(-\n)
            . qq(  not block implicit key\n)
            . qq(  but multi-lines\n)
            . qq(  plain text. \n)
        );

        is_deeply [strip l__block_sequence($s1, -1, 'block-in')],
            [
                strip $s1end,
                ['l+block-sequence',
                    ['ns-plain', qq(not compact implicit key )
                               . qq(but multi-lines )
                               . qq(plain text.)],
                    ['ns-plain', qq(not block implicit key )
                               . qq(but multi-lines )
                               . qq(plain text.)], ],
            ], spec;
}

