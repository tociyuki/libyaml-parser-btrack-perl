use strict;
use warnings;
use Carp;
use Test::More;
use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 23;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*c_ns_alias_node = \&YAML::Parser::Btrack::c_ns_alias_node;
*c_double_quoted = \&YAML::Parser::Btrack::c_double_quoted;
*c_single_quoted = \&YAML::Parser::Btrack::c_single_quoted;
*ns_plain = \&YAML::Parser::Btrack::ns_plain;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Alias Node';
    
        my $alias1 = derivs(qq(*anchor\n));
        my $alias1end = match($alias1, qq(*anchor));

    it 'should match alias.';
        is_deeply [strip c_ns_alias_node($alias1)],
            [strip $alias1end, ['c-ns-alias-node', '*anchor']], spec;

    it 'should not skip s-l-comments after alias.';

        my $alias2 = derivs(qq(*anchor # comment \n\n- entry next\n));
        my $alias2end = match($alias2, qq(*anchor));
        is_deeply [strip c_ns_alias_node($alias2)],
            [strip $alias2end, ['c-ns-alias-node', '*anchor']], spec;
}

{
    describe 'Double Quoted';

        my $exam7_4 = derivs(
              qq("implicit block key" : [\n)
            . qq(  "implicit flow key" : value,\n)
            . qq(]\n),
        );

        my $exam7_5 = derivs(
              qq(escape line break: "folded \n)
            . qq( to a space,\t\n)
            . qq(\n)
            . qq( to a line feed, or \t\\\n)
            . qq(   \\ \t non-content" # end),
        );

        my $exam7_6 = derivs(
              qq(folded: " 1st non-empty\n)
            . qq(\n)
            . qq(  2nd non-empty \n)
            . qq( \t3rd non-emtpy " # end),
        );

    it 'should match one line on block-key.';

        my $dq1 = $exam7_4;
        my $dq1end = match($dq1, qq("implicit block key"));
        is_deeply [strip c_double_quoted($dq1, 0, 'block-key')],
            [strip $dq1end, ['c-double-quoted', qq(implicit block key)]], spec;

    it 'should match one line on flow-key.';

        my $dq2 = match($exam7_4, qq("implicit block key" : [\n  ));
        my $dq2end = match($dq2, qq("implicit flow key"));
        is_deeply [strip c_double_quoted($dq2, 0, 'flow-key')],
            [strip $dq2end, ['c-double-quoted', qq(implicit flow key)]], spec;

    it 'should match multi lines and should fold them.';

        my $dq3 = match($exam7_6, qq(folded: ));
        my $dq3end = match($dq3,
              qq(" 1st non-empty\n)
            . qq(\n)
            . qq(  2nd non-empty \n)
            . qq( \t3rd non-emtpy "),
        );
        is_deeply [strip c_double_quoted($dq3, 1, 'flow-out')],
            [
                strip $dq3end,
                ['c-double-quoted',
                    qq( 1st non-empty\n2nd non-empty 3rd non-emtpy ),],
            ], spec;

    it 'should match escaped line.';

        my $dq4 = match($exam7_5, qq(escape line break: ));
        my $dq4end = match($dq4,
              qq("folded \n)
            . qq( to a space,\t\n)
            . qq(\n)
            . qq( to a line feed, or \t\\\n)
            . qq(   \\ \t non-content"),
        );
        is_deeply [strip c_double_quoted($dq4, 1, 'flow-out')],
            [
                strip $dq4end,
                ['c-double-quoted',
                    qq(folded to a space,\nto a line feed, or \t \t non-content),],
            ], spec;

    it 'should match escaped line another indent level.';

        my $dq5 = match($exam7_5, qq(escape line break: ));
        my $dq5end = match($dq5,
              qq("folded \n)
            . qq( to a space,\t\n)
            . qq(\n)
            . qq( to a line feed, or \t\\\n)
            . qq(   \\ \t non-content"),
        );
        is_deeply [strip c_double_quoted($dq5, 0, 'flow-out')],
            [
                strip $dq5end,
                ['c-double-quoted',
                    qq(folded to a space,\nto a line feed, or \t \t non-content),],
            ], spec;
}

{
    describe 'Single Quoted';

        my $exam7_7 = derivs(qq('here''s to "quoted"' # c-quoted-quote));
        my $exam7_8 = derivs(
              qq('implicit block key' : [\n)
            . qq(  'implicit flow key' : value,\n)
            . qq(]\n),
        );
        my $exam7_9 = derivs(
              qq(folded: ' 1st non-empty\n)
            . qq(\n)
            . qq(  2nd non-empty \n)
            . qq( \t3rd non-emtpy ' # end),
        );

    it 'should match quoted quotes.';

        my $sq1 = $exam7_7;
        my $sq1end = match($sq1, qq('here''s to "quoted"'));
        is_deeply [strip c_single_quoted($sq1, 0, 'flow-out')],
            [
                strip $sq1end,
                ['c-single-quoted', qq(here's to "quoted"),],
            ], spec;

    it 'should match block-key.';

        my $sq2 = $exam7_8;
        my $sq2end = match($sq2, qq('implicit block key'));
        is_deeply [strip c_single_quoted($sq2, 0, 'block-key')],
            [
                strip $sq2end,
                ['c-single-quoted', qq(implicit block key),],
            ], spec;

    it 'should match flow-key.';

        my $sq3 = match($exam7_8, qq('implicit block key' : [\n  ));
        my $sq3end = match($sq3, qq('implicit flow key'));
        is_deeply [strip c_single_quoted($sq3, 0, 'flow-key')],
            [
                strip $sq3end,
                ['c-single-quoted', qq(implicit flow key),],
            ], spec;

    it 'should match block-in.';

        my $sq4 = match($exam7_9, qq(folded: ));
        my $sq4end = match($sq4,
              qq(' 1st non-empty\n)
            . qq(\n)
            . qq(  2nd non-empty \n)
            . qq( \t3rd non-emtpy '),            
        );
        is_deeply [strip c_single_quoted($sq4, 1, 'block-in')],
            [
                strip $sq4end,
                ['c-single-quoted',
                    qq( 1st non-empty\n2nd non-empty 3rd non-emtpy ),],
            ], spec;
}

{
    describe 'Plain Style';

        my $exam7_10 = derivs(
              qq(# Outside flow collection:\n)  # ($n, $c) = (1, 'flow-out')
            . qq(- ::vector\n)
            . qq(- ": - ()"\n)
            . qq(- Up, up, and away!\n)
            . qq(- -123\n)
            . qq(- http://example.com/foo#bar\n)
            . qq(# Inside flow collection:\n)   # ($n, $c) = (1, 'flow-in')
            . qq(- [ ::vector,\n)
            . qq(  ": - ()",\n)
            . qq(  "Up, up and away!",\n)
            . qq(  -123,\n)
            . qq(  http://example.com/foo#bar ]\n),
        );
        my $exam7_11 = derivs(
              qq(implicit block key : [\n)      # ($n, $c) = (n/a, 'block-key')
            . qq(  implicit flow key : value,\n)# ($n, $c) = (n/a, 'flow-key')
            . qq(]\n),
        );
        my $exam7_12 = derivs(
              qq(1st non-empty\n)   # ($n, $c) = (0, 'flow-out')
            . qq(\n)
            . qq( 2nd non-empty \n)
            . qq(\t3rd non-empty\n)
            . qq(# end\n),
        );

    it 'should match flow-out ns-plain /:\S/.';

        my $p1 = match($exam7_10,
            qq(# Outside flow collection:\n)
            . qq(- )
        );
        my $p1end = match($p1, qq(::vector));
        is_deeply [strip ns_plain($p1, 1, 'flow-out')],
            [strip $p1end, ['ns-plain', qq(::vector)]], spec;

    it 'should match flow-out includings flow indicators.';

        my $p2 = match($exam7_10,
              qq(# Outside flow collection:\n)  # ($n, $c) = (1, 'flow-out')
            . qq(- ::vector\n)
            . qq(- ": - ()"\n)
            . qq(- ),
        );
        my $p2end = match($p2, qq(Up, up, and away!));
        is_deeply [strip ns_plain($p2, 1, 'flow-out')],
            [strip $p2end, ['ns-plain', qq(Up, up, and away!)]], spec;

    it 'should match flow-out ns-plain /-\S/.';

        my $p3 = match($exam7_10,
              qq(# Outside flow collection:\n)  # ($n, $c) = (1, 'flow-out')
            . qq(- ::vector\n)
            . qq(- ": - ()"\n)
            . qq(- Up, up, and away!\n)
            . qq(- ),
        );
        my $p3end = match($p3, qq(-123));
        is_deeply [strip ns_plain($p3, 1, 'flow-out')],
            [strip $p3end, ['ns-plain', qq(-123)]], spec;

    it 'should match flow-out ns-plain /\S\#/.';

        my $p4 = match($exam7_10,
              qq(# Outside flow collection:\n)  # ($n, $c) = (1, 'flow-out')
            . qq(- ::vector\n)
            . qq(- ": - ()"\n)
            . qq(- Up, up, and away!\n)
            . qq(- -123\n)
            . qq(- )
        );
        my $p4end = match($p4, qq(http://example.com/foo#bar));
        is_deeply [strip ns_plain($p4, 1, 'flow-out')],
            [strip $p4end, ['ns-plain', qq(http://example.com/foo#bar)]], spec;

    it 'should match flow-in ns-plain /:\S/.';

        my $p5 = match($exam7_10,
              qq(# Outside flow collection:\n)  # ($n, $c) = (1, 'flow-out')
            . qq(- ::vector\n)
            . qq(- ": - ()"\n)
            . qq(- Up, up, and away!\n)
            . qq(- -123\n)
            . qq(- http://example.com/foo#bar\n)
            . qq(# Inside flow collection:\n)   # ($n, $c) = (1, 'flow-in')
            . qq(- [ )
        );
        my $p5end = match($p5, qq(::vector));
        is_deeply [strip ns_plain($p5, 1, 'flow-in')],
            [strip $p5end, ['ns-plain', qq(::vector)]], spec;

    it 'should match flow-in ns-plain /-\S/.';

        my $p6 = match($exam7_10,
              qq(# Outside flow collection:\n)  # ($n, $c) = (1, 'flow-out')
            . qq(- ::vector\n)
            . qq(- ": - ()"\n)
            . qq(- Up, up, and away!\n)
            . qq(- -123\n)
            . qq(- http://example.com/foo#bar\n)
            . qq(# Inside flow collection:\n)   # ($n, $c) = (1, 'flow-in')
            . qq(- [ ::vector,\n)
            . qq(  ": - ()",\n)
            . qq(  "Up, up and away!",\n)
            . qq(  )
        );
        my $p6end = match($p6, qq(-123));
        is_deeply [strip ns_plain($p6, 1, 'flow-in')],
            [strip $p6end, ['ns-plain', qq(-123)]], spec;

    it 'should match flow-in ns-plain /\S\#/.';

        my $p7 = match($exam7_10,
              qq(# Outside flow collection:\n)  # ($n, $c) = (1, 'flow-out')
            . qq(- ::vector\n)
            . qq(- ": - ()"\n)
            . qq(- Up, up, and away!\n)
            . qq(- -123\n)
            . qq(- http://example.com/foo#bar\n)
            . qq(# Inside flow collection:\n)   # ($n, $c) = (1, 'flow-in')
            . qq(- [ ::vector,\n)
            . qq(  ": - ()",\n)
            . qq(  "Up, up and away!",\n)
            . qq(  -123,\n)
            . qq(  ),
        );
        my $p7end = match($p7, qq(http://example.com/foo#bar));
        is_deeply [strip ns_plain($p7, 1, 'flow-in')],
            [strip $p7end, ['ns-plain', qq(http://example.com/foo#bar)]], spec;

    it 'should match block-key.';

        my $p8 = $exam7_11;
        my $p8end = match($p8, qq(implicit block key));
        is_deeply [strip ns_plain($p8, 0, 'block-key')],
            [strip $p8end, ['ns-plain', qq(implicit block key)]], spec;

    it 'should match flow-key.';

        my $p9 = match($exam7_11,
              qq(implicit block key : [\n)      # ($n, $c) = (n/a, 'block-key')
            . qq(  )# ($n, $c) = (n/a, 'flow-key')
        );
        my $p9end = match($p9, qq(implicit flow key));
        is_deeply [strip ns_plain($p9, 0, 'flow-key')],
            [strip $p9end, ['ns-plain', qq(implicit flow key)]], spec;

    it 'should match multi lines.';

        my $p10 = $exam7_12;
        my $p10end = match($p10,
              qq(1st non-empty\n)   # ($n, $c) = (0, 'flow-out')
            . qq(\n)
            . qq( 2nd non-empty \n)
            . qq(\t3rd non-empty),
        );
        is_deeply [strip ns_plain($p10, 0, 'flow-out')],
            [   strip $p10end,
                ['ns-plain',
                    qq(1st non-empty\n2nd non-empty 3rd non-empty)],
            ], spec;

    it 'should match multi lines before directive end line.';

        my $p11 = derivs(
              qq(1st non-empty\n)   # ($n, $c) = (0, 'flow-out')
            . qq(\n)
            . qq( 2nd non-empty \n)
            . qq(\t3rd non-empty\n)
            . qq(---\n)
        );
        my $p11end = match($p11,
              qq(1st non-empty\n)   # ($n, $c) = (0, 'flow-out')
            . qq(\n)
            . qq( 2nd non-empty \n)
            . qq(\t3rd non-empty),
        );
        is_deeply [strip ns_plain($p11, 0, 'flow-out')],
            [   strip $p11end,
                ['ns-plain',
                    qq(1st non-empty\n2nd non-empty 3rd non-empty)],
            ], spec;

    it 'should match multi lines before document end line.';

        my $p12 = derivs(
              qq(1st non-empty\n)   # ($n, $c) = (0, 'flow-out')
            . qq(\n)
            . qq( 2nd non-empty \n)
            . qq(\t3rd non-empty\n)
            . qq(...\n)
        );
        my $p12end = match($p12,
              qq(1st non-empty\n)   # ($n, $c) = (0, 'flow-out')
            . qq(\n)
            . qq( 2nd non-empty \n)
            . qq(\t3rd non-empty),
        );
        is_deeply [strip ns_plain($p12, 0, 'flow-out')],
            [   strip $p12end,
                ['ns-plain',
                    qq(1st non-empty\n2nd non-empty 3rd non-empty)],
            ], spec;
}

