use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 7;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*s_l__block_node = \&YAML::Parser::Btrack::s_l__block_node;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Block Nodes';

    it 'should match example 8.20.';

        my $s1 = derivs(
              qq(-\n)
            . qq(  "flow in block"\n)
            . qq(- >\n)
            . qq( Block scalar\n)
            . qq(- !!map # Block collection\n)
            . qq(  foo : bar\n)
            . qq(---\n),
        );
        my $s1end = match($s1,
              qq(-\n)
            . qq(  "flow in block"\n)
            . qq(- >\n)
            . qq( Block scalar\n)
            . qq(- !!map # Block collection\n)
            . qq(  foo : bar\n)
        );

        is_deeply [strip s_l__block_node($s1, -1, 'block-in')],
            [
                strip $s1end,
                ['l+block-sequence',
                    ['c-double-quoted', qq(flow in block)],
                    ['c-l+folded', qq(Block scalar\n)],
                    ['c-ns-properties', ['c-ns-tag-property', '!!map'], undef,
                        ['l+block-mapping',
                            ['ns-plain', 'foo'], ['ns-plain', 'bar'], ], ], ],
            ], spec;

    it 'should match example 8.21.';

        my $s2 = derivs(
              qq(literal: |2\n)
            . qq(  value\n)
            . qq(folded:\n)
            . qq(   !foo\n)
            . qq(  >1\n)
            . qq( value\n)
            . qq(---\n),
        );
        my $s2end = match($s2,
              qq(literal: |2\n)
            . qq(  value\n)
            . qq(folded:\n)
            . qq(   !foo\n)
            . qq(  >1\n)
            . qq( value\n),
        );

        is_deeply [strip s_l__block_node($s2, -1, 'block-in')],
            [
                strip $s2end,
                ['l+block-mapping',
                    ['ns-plain', 'literal'], ['c-l+literal', qq(value\n)],
                    ['ns-plain', 'folded'],
                    ['c-ns-properties', ['c-ns-tag-property', '!foo'], undef,
                        ['c-l+folded', qq(value\n)], ], ],
            ], spec;

    it 'should match example 8.22.';

        my $s3 = derivs(
              qq(sequence: !!seq\n)
            . qq(- entry\n)
            . qq(- !!seq\n)
            . qq( - nested\n)
            . qq(mapping: !!map\n)
            . qq( foo: bar\n)
            . qq(---\n),
        );
        my $s3end = match($s3,
              qq(sequence: !!seq\n)
            . qq(- entry\n)
            . qq(- !!seq\n)
            . qq( - nested\n)
            . qq(mapping: !!map\n)
            . qq( foo: bar\n),
        );

        is_deeply [strip s_l__block_node($s3, -1, 'block-in')],
            [
                strip $s3end,
                ['l+block-mapping',
                    ['ns-plain', 'sequence'],
                    ['c-ns-properties', ['c-ns-tag-property', '!!seq'], undef,
                        ['l+block-sequence',
                            ['ns-plain', 'entry'],
                            ['c-ns-properties', ['c-ns-tag-property', '!!seq'], undef,
                                ['l+block-sequence',
                                    ['ns-plain', 'nested'], ], ], ], ],
                    ['ns-plain', 'mapping'],
                    ['c-ns-properties', ['c-ns-tag-property', '!!map'], undef,
                        ['l+block-mapping',
                            ['ns-plain', 'foo'], ['ns-plain', 'bar'], ], ], ],
            ], spec;

    it 'should match bare document.';

        my $s4 = derivs(
              qq(Bare\n)
            . qq(document\n)
            . qq(...\n)
        );
        my $s4end = match($s4,
              qq(Bare\n)
            . qq(document\n)
        );

        is_deeply [strip s_l__block_node($s4, -1, 'block-in')],
            [
                strip $s4end,
                ['ns-plain', qq(Bare document)],
            ], spec;
            
}

{
    it 'should match block mapping property and block key property.';

        my $s1 = derivs(
              qq(!!map\n)
            . qq(  !!str : implicit entry\n)
            . qq(...\n)
        );
        my $s1end = match($s1,
              qq(!!map\n)
            . qq(  !!str : implicit entry\n)
        );

        is_deeply [strip s_l__block_node($s1, -1, 'block-in')],
            [
                strip $s1end,
                ['c-ns-properties', ['c-ns-tag-property', '!!map'], undef,
                    ['l+block-mapping',
                        ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                            ['e-scalar'], ],
                        ['ns-plain', 'implicit entry'], ], ],
            ], spec

    it 'should match block mapping property.';

        my $s2 = derivs(
              qq(!!map\n)
            . qq(  implicit key : implicit entry\n)
            . qq(...\n)
        );
        my $s2end = match($s2,
              qq(!!map\n)
            . qq(  implicit key : implicit entry\n)
        );

        is_deeply [strip s_l__block_node($s2, -1, 'block-in')],
            [
                strip $s2end,
                ['c-ns-properties', ['c-ns-tag-property', '!!map'], undef,
                    ['l+block-mapping',
                        ['ns-plain', 'implicit key'],
                        ['ns-plain', 'implicit entry'], ], ],
            ], spec

    it 'should match first block implicit key property.';

        my $s3 = derivs(
              qq(\n)
            . qq(  !!str : implicit entry\n)
            . qq(...\n)
        );
        my $s3end = match($s3,
              qq(\n)
            . qq(  !!str : implicit entry\n)
        );

        is_deeply [strip s_l__block_node($s3, -1, 'block-in')],
            [
                strip $s3end,
                ['l+block-mapping',
                    ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['e-scalar'], ],
                    ['ns-plain', 'implicit entry'], ],
            ], spec
}

