use strict;
use warnings;
use Carp;
use Test::More;
use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 17;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*c_l__block_scalar = \&YAML::Parser::Btrack::c_l__block_scalar;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Block Literal';

    it 'should match clip indicator';
        my $s1all = derivs(
              qq(literal: |\n)
            . qq(  literal\n)
            . qq(   text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n)
            . qq(other:\n),
        );
        my $s1 = match($s1all, qq(literal: ));
        my $s1end = match($s1,
              qq(|\n)
            . qq(  literal\n)
            . qq(   text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n),
        );
        is_deeply [strip c_l__block_scalar($s1, 1)],
            [
                strip $s1end,
                ['c-l+literal', qq(literal\n text\n)],
            ], spec;

    it 'should match strip indicator';
        my $s2all = derivs(
              qq(literal: |-\n)
            . qq(  literal\n)
            . qq(   text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # strip\n)
            . qq(  # comments\n)
            . qq(other:\n),
        );
        my $s2 = match($s2all, qq(literal: ));
        my $s2end = match($s2,
              qq(|-\n)
            . qq(  literal\n)
            . qq(   text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # strip\n)
            . qq(  # comments\n),
        );
        is_deeply [strip c_l__block_scalar($s2, 1)],
            [
                strip $s2end,
                ['c-l+literal', qq(literal\n text)],
            ], spec;

    it 'should match keep indicator';
        my $s3all = derivs(
              qq(literal: |+\n)
            . qq(  literal\n)
            . qq(   text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # keep\n)
            . qq(  # comments\n)
            . qq(other:\n),
        );
        my $s3 = match($s3all, qq(literal: ));
        my $s3end = match($s3,
              qq(|+\n)
            . qq(  literal\n)
            . qq(   text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # keep\n)
            . qq(  # comments\n)
        );
        is_deeply [strip c_l__block_scalar($s3, 1)],
            [
                strip $s3end,
                ['c-l+literal', qq(literal\n text\n\n\n)],
            ], spec;

    it 'should match indentation indicator';
        my $s4all = derivs(
              qq(literal: |2\n)
            . qq(     literal\n)
            . qq(    text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n)
            . qq(other:\n),
        );
        my $s4 = match($s4all, qq(literal: ));
        my $s4end = match($s4,
              qq(|2\n)
            . qq(     literal\n)
            . qq(    text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n),
        );
        is_deeply [strip c_l__block_scalar($s4, 2)],
            [
                strip $s4end,
                ['c-l+literal', qq( literal\ntext\n)],
            ], spec;

    it 'should match indentation and chomping indicator';
        my $s5all = derivs(
              qq(literal: |2+\n)
            . qq(     literal\n)
            . qq(    text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n)
            . qq(other:\n),
        );
        my $s5 = match($s5all, qq(literal: ));
        my $s5end = match($s5,
              qq(|2+\n)
            . qq(     literal\n)
            . qq(    text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n),
        );
        is_deeply [strip c_l__block_scalar($s5, 2)],
            [
                strip $s5end,
                ['c-l+literal', qq( literal\ntext\n\n\n)],
            ], spec;

    it 'should match chomping and indentation indicator';
        my $s6all = derivs(
              qq(literal: |+2\n)
            . qq(     literal\n)
            . qq(    text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n)
            . qq(other:\n),
        );
        my $s6 = match($s6all, qq(literal: ));
        my $s6end = match($s6,
              qq(|+2\n)
            . qq(     literal\n)
            . qq(    text\n)
            . qq(\n)
            . qq(  \n)
            . qq( # clip\n)
            . qq(  # comments\n),
        );
        is_deeply [strip c_l__block_scalar($s6, 2)],
            [
                strip $s6end,
                ['c-l+literal', qq( literal\ntext\n\n\n)],
            ], spec;

    it 'should match s-b-comment.';

        my $s7 = derivs(
              qq(| # comment\n)
            . qq(  # content\n)
            . qq(  \n)
            . qq(  literal\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# clip\n)
            . qq(---\n),
        );
        my $s7end = match($s7,
              qq(| # comment\n)
            . qq(  # content\n)
            . qq(  \n)
            . qq(  literal\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# clip\n)
        );
        is_deeply [strip c_l__block_scalar($s7, 0)],
            [
                strip $s7end,
                ['c-l+literal',
                      qq(# content\n)
                    . qq(\n)
                    . qq(literal\n)
                    . qq(text\n), ],
            ], spec;

    it 'should stop before directive end line.';

        my $s8 = derivs(
              qq(|\n)
            . qq(literal\n)
            . qq(text\n)
            . qq(---\n)
        );
        my $s8end = match($s8,
              qq(|\n)
            . qq(literal\n)
            . qq(text\n)
        );
        is_deeply [strip c_l__block_scalar($s8, 0)],
            [
                strip $s8end,
                ['c-l+literal',
                      qq(literal\n)
                    . qq(text\n), ],
            ], spec;

    it 'should stop before document end line.';

        my $s9 = derivs(
              qq(|\n)
            . qq(literal\n)
            . qq(text\n)
            . qq(...\n)
        );
        my $s9end = match($s9,
              qq(|\n)
            . qq(literal\n)
            . qq(text\n)
        );
        is_deeply [strip c_l__block_scalar($s9, 0)],
            [
                strip $s9end,
                ['c-l+literal',
                      qq(literal\n)
                    . qq(text\n), ],
            ], spec;
}

{
    describe 'Block Folded';

    it 'should fold lines.';

        my $s1 = derivs(
              qq(>\n)
            . qq( folded\n)
            . qq( text\n)
            . qq(\n)
            . qq(# comment\n)
            . qq(---\n),
        );
        my $s1end = match($s1,
              qq(>\n)
            . qq( folded\n)
            . qq( text\n)
            . qq(\n)
            . qq(# comment\n)
        );
        is_deeply [strip c_l__block_scalar($s1, 0)],
            [
                strip $s1end,
                ['c-l+folded', qq(folded text\n)],
            ], spec;

    it 'should fold lines not starting white space characters.';

        my $s2 = derivs(
              qq(>\n)
            . qq(\n)
            . qq( folded\n)
            . qq( line\n)
            . qq(\n)
            . qq( next\n)
            . qq( line\n)
            . qq(   * bullet\n)
            . qq(\n)
            . qq(   * list\n)
            . qq(   * lines\n)
            . qq(\n)
            . qq( last\n)
            . qq( line\n)
            . qq(\n)
            . qq(# Comment\n)
            . qq(---\n),
        );
        my $s2end = match($s2,
              qq(>\n)
            . qq(\n)
            . qq( folded\n)
            . qq( line\n)
            . qq(\n)
            . qq( next\n)
            . qq( line\n)
            . qq(   * bullet\n)
            . qq(\n)
            . qq(   * list\n)
            . qq(   * lines\n)
            . qq(\n)
            . qq( last\n)
            . qq( line\n)
            . qq(\n)
            . qq(# Comment\n)
        );
        is_deeply [strip c_l__block_scalar($s2, 0)],
            [
                strip $s2end,
                ['c-l+folded',
                      qq(\n)
                    . qq(folded line\n)
                    . qq(next line\n)
                    . qq(  * bullet\n)
                    . qq(\n)
                    . qq(  * list\n)
                    . qq(  * lines\n)
                    . qq(\n)
                    . qq(last line\n), ],
            ], spec;

    it 'should fold lines and keep trail line feeds.';

        my $s3 = derivs(
              qq(>+\n)
            . qq( folded\n)
            . qq( text\n)
            . qq(\n)
            . qq(# keep\n)
            . qq(---\n),
        );
        my $s3end = match($s3,
              qq(>+\n)
            . qq( folded\n)
            . qq( text\n)
            . qq(\n)
            . qq(# keep\n)
        );
        is_deeply [strip c_l__block_scalar($s3, 0)],
            [
                strip $s3end,
                ['c-l+folded', qq(folded text\n\n)],
            ], spec;

    it 'should fold lines and strip trail line feeds.';

        my $s4 = derivs(
              qq(>-\n)
            . qq( folded\n)
            . qq( text\n)
            . qq(\n)
            . qq(# strip\n)
            . qq(---\n),
        );
        my $s4end = match($s4,
              qq(>-\n)
            . qq( folded\n)
            . qq( text\n)
            . qq(\n)
            . qq(# strip\n)
        );
        is_deeply [strip c_l__block_scalar($s4, 0)],
            [
                strip $s4end,
                ['c-l+folded', qq(folded text)],
            ], spec;

    it 'should match indentation indicator.';

        my $s5 = derivs(
              qq(>2\n)
            . qq(   folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# clip\n)
            . qq(---\n),
        );
        my $s5end = match($s5,
              qq(>2\n)
            . qq(   folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# clip\n)
        );
        is_deeply [strip c_l__block_scalar($s5, 0)],
            [
                strip $s5end,
                ['c-l+folded', qq( folded\ntext\n)],
            ], spec;

    it 'should match indentation and chomping indicator.';

        my $s6 = derivs(
              qq(>2-\n)
            . qq(   folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# strip\n)
            . qq(---\n),
        );
        my $s6end = match($s6,
              qq(>2-\n)
            . qq(   folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# strip\n)
        );
        is_deeply [strip c_l__block_scalar($s6, 0)],
            [
                strip $s6end,
                ['c-l+folded', qq( folded\ntext)],
            ], spec;

    it 'should match chomping and indentation indicator.';

        my $s7 = derivs(
              qq(>-2\n)
            . qq(   folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# strip\n)
            . qq(---\n),
        );
        my $s7end = match($s7,
              qq(>-2\n)
            . qq(   folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# strip\n)
        );
        is_deeply [strip c_l__block_scalar($s7, 0)],
            [
                strip $s7end,
                ['c-l+folded', qq( folded\ntext)],
            ], spec;

    it 'should match s-b-comment.';

        my $s8 = derivs(
              qq(> # comment\n)
            . qq(  # content\n)
            . qq(  \n)
            . qq(  folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# clip\n)
            . qq(---\n),
        );
        my $s8end = match($s8,
              qq(> # comment\n)
            . qq(  # content\n)
            . qq(  \n)
            . qq(  folded\n)
            . qq(  text\n)
            . qq(\n)
            . qq(# clip\n)
        );
        is_deeply [strip c_l__block_scalar($s8, 0)],
            [
                strip $s8end,
                ['c-l+folded',
                      qq(# content\n)
                    . qq(folded text\n)],
            ], spec;
}

