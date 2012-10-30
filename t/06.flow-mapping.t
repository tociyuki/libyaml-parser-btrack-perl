use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 34;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*c_flow_mapping = \&YAML::Parser::Btrack::c_flow_mapping;
*ns_flow_map_entry = \&YAML::Parser::Btrack::ns_flow_map_entry ;
*c_flow_sequence = \&YAML::Parser::Btrack::c_flow_sequence ;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Flow YAML Key Entry';

    it q(should match k: v.);

        my $e1 = derivs(qq(k: v,\n));
        my $e1end = match($e1, qq(k: v));
        is_deeply [strip ns_flow_map_entry($e1, 1, 'flow-in')],
            [strip $e1end,
                [['ns-plain', 'k'], ['ns-plain', 'v']],
            ], spec;

    it q(should match k : v.);

        my $e2 = derivs(qq(k : v,\n));
        my $e2end = match($e2, qq(k : v));
        is_deeply [strip ns_flow_map_entry($e2, 1, 'flow-in')],
            [strip $e2end,
                [['ns-plain', 'k'], ['ns-plain', 'v']],
            ], spec;

    it q(should match !!str k: v.);

        my $e3 = derivs(qq(!!str k: v,\n));
        my $e3end = match($e3, qq(!!str k: v));
        is_deeply [strip ns_flow_map_entry($e3, 1, 'flow-in')],
            [strip $e3end,
                [   ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['ns-plain', 'k'], ],
                    ['ns-plain', 'v'], ],
            ], spec;

    it q(should match !!str : v.);

        my $e4 = derivs(qq(!!str : v\n));
        my $e4end = match($e4, qq(!!str : v));
        is_deeply [strip ns_flow_map_entry($e4, 1, 'flow-in')],
            [strip $e4end,
                [   ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['e-scalar'], ],
                    ['ns-plain', 'v'], ],
            ], spec;

    it q(should match *a : v.);

        my $e5 = derivs(qq(*a : v,\n));
        my $e5end = match($e5, qq(*a : v));
        is_deeply [strip ns_flow_map_entry($e5, 1, 'flow-in')],
            [strip $e5end,
                [['c-ns-alias-node', '*a'], ['ns-plain', 'v']],
            ], spec;

    it q(should match k:k: v.);

        my $e6 = derivs(qq(k:k: v,\n));
        my $e6end = match($e6, qq(k:k: v));
        is_deeply [strip ns_flow_map_entry($e6, 1, 'flow-in')],
            [strip $e6end,
                [['ns-plain', 'k:k'], ['ns-plain', 'v']],
            ], spec;

    it q(should match k,.);

        my $e7 = derivs(qq(k,\n));
        my $e7end = match($e7, qq(k));
        is_deeply [strip ns_flow_map_entry($e7, 1, 'flow-in')],
            [strip $e7end,
                [['ns-plain', 'k'], ['e-scalar']],
            ], spec;

    it q(should match k:,.);

        my $e8 = derivs(qq(k:,\n));
        my $e8end = match($e8, qq(k:));
        is_deeply [strip ns_flow_map_entry($e8, 1, 'flow-in')],
            [strip $e8end,
                [['ns-plain', 'k'], ['e-scalar']],
            ], spec;

    it q(should not match ,);

        my $e9 = derivs(qq(, k :\n));
        is_deeply [strip ns_flow_map_entry($e9, 1, 'flow-in')], [], spec;

    it q(should not match });

        my $e10 = derivs(qq(}\n));
        is_deeply [strip ns_flow_map_entry($e10, 1, 'flow-in')], [], spec;

    it q(should not match ]);

        my $e11 = derivs(qq(]\n));
        is_deeply [strip ns_flow_map_entry($e11, 1, 'flow-in')], [], spec;

    it q(should match !!str :.);

        my $e12 = derivs(qq(!!str :,\n));
        my $e12end = match($e12, qq(!!str :));
        is_deeply [strip ns_flow_map_entry($e12, 1, 'flow-in')],
            [strip $e12end,
                [   ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['e-scalar'], ],
                    ['e-scalar'], ],
            ], spec;

    it q(should match !!str,.);

        my $e13 = derivs(qq(!!str,\n));
        my $e13end = match($e13, qq(!!str));
        is_deeply [strip ns_flow_map_entry($e13, 1, 'flow-in')],
            [strip $e13end,
                [   ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['e-scalar'], ],
                    ['e-scalar'], ],
            ], spec;
}

{
    describe 'Flow Empty Key Entry';

    it q(should match : a,);

        my $e1 = derivs(qq(: a,\n));
        my $e1end = match($e1, qq(: a));
        is_deeply [strip ns_flow_map_entry($e1, 1, 'flow-in')],
            [strip $e1end,
                [['e-scalar'], ['ns-plain', 'a']],
            ], spec;

    it q(should match :,);

        my $e2 = derivs(qq(:,\n));
        my $e2end = match($e2, qq(:));
        is_deeply [strip ns_flow_map_entry($e2, 1, 'flow-in')],
            [strip $e2end,
                [['e-scalar'], ['e-scalar']],
            ], spec;
}

{
    describe 'Flow JSON Key Entry';

    it q(should match 'k': 'v'.);

        my $e1 = derivs(qq('k': 'v',));
        my $e1end = match($e1, qq('k': 'v'));
        is_deeply [strip ns_flow_map_entry($e1, 1, 'flow-in')],
            [strip $e1end,
                [['c-single-quoted', 'k'], ['c-single-quoted', 'v']],
            ], spec;

    it q(should match 'k':'v'.);

        my $e2 = derivs(qq('k':'v',));
        my $e2end = match($e2, qq('k':'v'));
        is_deeply [strip ns_flow_map_entry($e2, 1, 'flow-in')],
            [strip $e2end,
                [['c-single-quoted', 'k'], ['c-single-quoted', 'v']],
            ], spec;

    it q(should match !!str 'k': 'v'.);

        my $e3 = derivs(qq(!!str 'k': 'v',));
        my $e3end = match($e3, qq(!!str 'k': 'v'));
        is_deeply [strip ns_flow_map_entry($e3, 1, 'flow-in')],
            [strip $e3end,
                [   ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['c-single-quoted', 'k'], ],
                    ['c-single-quoted', 'v'], ],
            ], spec;

    it q(should match !!str 'k': !!str 'v'.);

        my $e4 = derivs(qq(!!str 'k': !!str 'v',));
        my $e4end = match($e4, qq(!!str 'k': !!str 'v'));
        is_deeply [strip ns_flow_map_entry($e4, 1, 'flow-in')],
            [strip $e4end,
                [   ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['c-single-quoted', 'k'], ],
                    ['c-ns-properties', ['c-ns-tag-property', '!!str'], undef,
                        ['c-single-quoted', 'v'], ], ],
            ], spec;
}

{
    describe 'Flow Explicit Key Entry';

    it q(should match ? A : a,);

        my $e1 = derivs(qq(? A : a,));
        my $e1end = match($e1, qq(? A : a));
        is_deeply [strip ns_flow_map_entry($e1, 1, 'flow-in')],
            [strip $e1end,
                [['ns-plain', 'A'], ['ns-plain', 'a']],
            ], spec;

    it q(should match ? A,);

        my $e2 = derivs(qq(? A,));
        my $e2end = match($e2, qq(? A));
        is_deeply [strip ns_flow_map_entry($e2, 1, 'flow-in')],
            [strip $e2end,
                [['ns-plain', 'A'], ['e-scalar']],
            ], spec;

    it q(should match ? : a,);

        my $e3 = derivs(qq(? : a,));
        my $e3end = match($e3, qq(? : a));
        is_deeply [strip ns_flow_map_entry($e3, 1, 'flow-in')],
            [strip $e3end,
                [['e-scalar'], ['ns-plain', 'a']],
            ], spec;

    it q(should match ? : ,);

        my $e4 = derivs(qq(? : ,));
        my $e4end = match($e4, qq(? :));
        is_deeply [strip ns_flow_map_entry($e4, 1, 'flow-in')],
            [strip $e4end,
                [['e-scalar'], ['e-scalar']],
            ], spec;

    it q(should match ? ,);

        my $e5 = derivs(qq(? ,));
        my $e5end = match($e5, qq(? ));
        is_deeply [strip ns_flow_map_entry($e5, 1, 'flow-in')],
            [strip $e5end,
                [['e-scalar'], ['e-scalar']],
            ], spec;
}

{
    describe 'Flow Mapping';

    it q(should match {}.);

        my $e1 = derivs(qq({}\n));
        my $e1end = match($e1, qq({}));
        is_deeply [strip c_flow_mapping($e1, 1, 'flow-out')],
            [strip $e1end,
                ['c-flow-mapping'],
            ], spec;

    it q(should match { A : a }.);

        my $e2 = derivs(qq({ A : a }\n));
        my $e2end = match($e2, qq({ A : a }));
        is_deeply [strip c_flow_mapping($e2, 1, 'flow-out')],
            [strip $e2end,
                ['c-flow-mapping',
                    ['ns-plain', 'A'], ['ns-plain', 'a'], ],
            ], spec;

    it q(should match { A: a, }.);

        my $e3 = derivs(qq({ A: a, }\n));
        my $e3end = match($e3, qq({ A: a, }));
        is_deeply [strip c_flow_mapping($e3, 1, 'flow-out')],
            [strip $e3end,
                ['c-flow-mapping',
                    ['ns-plain', 'A'], ['ns-plain', 'a'], ],
            ], spec;

    it q(should match { A: a, B: b }.);

        my $e4 = derivs(qq({ A: a, B: b }\n));
        my $e4end = match($e4, qq({ A: a, B: b }));
        is_deeply [strip c_flow_mapping($e4, 1, 'flow-out')],
            [strip $e4end,
                ['c-flow-mapping',
                    ['ns-plain', 'A'], ['ns-plain', 'a'],
                    ['ns-plain', 'B'], ['ns-plain', 'b'], ],
            ], spec;

    it q(should match { A: a, B: b, }.);

        my $e5 = derivs(qq({ A: a, B: b, }\n));
        my $e5end = match($e5, qq({ A: a, B: b, }));
        is_deeply [strip c_flow_mapping($e5, 1, 'flow-out')],
            [strip $e5end,
                ['c-flow-mapping',
                    ['ns-plain', 'A'], ['ns-plain', 'a'],
                    ['ns-plain', 'B'], ['ns-plain', 'b'], ],
            ], spec;

    it q(should match { A: a, B: {B0: b0}, C: c }.);

        my $e6 = derivs(qq({ A: a, B: {B0: b0}, C: c }\n));
        my $e6end = match($e6, qq({ A: a, B: {B0: b0}, C: c }));
        is_deeply [strip c_flow_mapping($e6, 1, 'flow-out')],
            [strip $e6end,
                ['c-flow-mapping',
                    ['ns-plain', 'A'], ['ns-plain', 'a'],
                    ['ns-plain', 'B'],
                        ['c-flow-mapping', ['ns-plain', 'B0'], ['ns-plain', 'b0']],
                    ['ns-plain', 'C'], ['ns-plain', 'c'],
                    ],
            ], spec;

    it q(should match { A: a, {B: b} : b0, C: c }.);

        my $e7 = derivs(qq({ A: a, {B: b} : b0, C: c }\n));
        my $e7end = match($e7, qq({ A: a, {B: b} : b0, C: c }));
        is_deeply [strip c_flow_mapping($e7, 1, 'flow-out')],
            [strip $e7end,
                ['c-flow-mapping',
                    ['ns-plain', 'A'], ['ns-plain', 'a'],
                    ['c-flow-mapping', ['ns-plain', 'B'], ['ns-plain', 'b']],
                        ['ns-plain', 'b0'],
                    ['ns-plain', 'C'], ['ns-plain', 'c'],
                    ],
            ], spec;
}

{
    describe 'Flow Pair';

    it 'should match implicit pair.';

        my $s1 = derivs(
              qq([ a, single: pair, B: b, c ]\n)
            . qq(...\n)
        );
        my $s1end = match($s1,
              qq([ a, single: pair, B: b, c ])
        );

        is_deeply [strip c_flow_sequence($s1, 1, 'flow-out')],
            [
                strip $s1end,
                ['c-flow-sequence',
                    ['ns-plain', 'a'],
                    ['c-flow-mapping',
                        ['ns-plain', 'single'], ['ns-plain', 'pair'], ],
                    ['c-flow-mapping',
                        ['ns-plain', 'B'], ['ns-plain', 'b'], ],
                    ['ns-plain', 'c'], ],
            ], spec;

    it 'should match explicit pair.';

        my $s2 = derivs(
              qq([\n)
            . qq(? foo\n)
            . qq( bar : baz\n)
            . qq(]\n)
        );
        my $s2end = match($s2,
              qq([\n)
            . qq(? foo\n)
            . qq( bar : baz\n)
            . qq(])
        );

        is_deeply [strip c_flow_sequence($s2, 0, 'flow-out')],
            [
                strip $s2end,
                ['c-flow-sequence',
                    ['c-flow-mapping',
                        ['ns-plain', 'foo bar'], ['ns-plain', 'baz'], ], ],
            ], spec;

    it 'should match modified example 7.21.';

        my $s3 = derivs(
              qq([ YAML : separtate, : empty key entry , {JSON: like}:adjacent ]\n)
        );
        my $s3end = match($s3,
              qq([ YAML : separtate, : empty key entry , {JSON: like}:adjacent ])
        );

        is_deeply [strip c_flow_sequence($s3, 0, 'flow-out')],
            [
                strip $s3end,
                ['c-flow-sequence',
                    ['c-flow-mapping',
                        ['ns-plain', 'YAML'], ['ns-plain', 'separtate'], ],
                    ['c-flow-mapping',
                        ['e-scalar'], ['ns-plain', 'empty key entry'], ],
                    ['c-flow-mapping',
                        ['c-flow-mapping',
                            ['ns-plain', 'JSON'], ['ns-plain', 'like'], ],
                        ['ns-plain', 'adjacent'], ],
                ],
            ], spec;
}

