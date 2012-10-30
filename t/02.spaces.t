use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 25;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*s_separate_in_line = \&YAML::Parser::Btrack::s_separate_in_line;
*s_b_comment = \&YAML::Parser::Btrack::s_b_comment;
*s_l_comments = \&YAML::Parser::Btrack::s_l_comments;
*s_separate = \&YAML::Parser::Btrack::s_separate;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Separation';

        my $sep = derivs("- for:\t bar\n");

    it 'should match start of line.';

        is_deeply [strip s_separate_in_line(derivs($sep, 0))],
            [strip derivs($sep, 0), q()], spec;

    it 'should match pos==1 separator between "-" and "for".';

        is_deeply [strip s_separate_in_line(derivs($sep, 1))],
            [strip derivs($sep, 2), q( )], spec;

    it 'should not match pos==2 on word "for".';

        is_deeply [s_separate_in_line(derivs($sep, 2))], [], spec;

    it 'should match pos==6 between ":" and "bar".';

        is_deeply [strip s_separate_in_line(derivs($sep, 6))],
            [strip derivs($sep, 8), "\t "], spec;

    it 'should not match pos==11 at end of line.';

        is_deeply [s_separate_in_line(derivs($sep, 11))], [], spec;
}

{
    describe 'Comment';

        my $exam6_9 = derivs(
              qq(key:    # Comment\n)
            . qq(  value)
        );
        my $exam6_9comment = match($exam6_9, qq(key:));
        my $exam6_9bol = match($exam6_9comment, qq(    # Comment\n));
        my $exam6_9eof = match($exam6_9bol, qq(  value));

    it 'should match after colon.';

        is_deeply [strip s_b_comment($exam6_9comment)],
            [strip $exam6_9bol, qq(    # Comment\n)], spec;

    it 'should match end of file.';

        is_deeply [strip s_b_comment($exam6_9eof)],
            [strip $exam6_9eof, q()], spec;

    it 'should match end of line.';

        my $foo2 = derivs(qq(foo\nbar\n));
        my $foo2eol = match($foo2, qq(foo));
        my $foo2bol = match($foo2eol, qq(\n));

        is_deeply [strip s_b_comment($foo2eol)],
            [strip $foo2bol, qq(\n)], spec;

    it 'should match comment line.';

        my $foo3 = derivs(qq(foo\n# comment \nbar\n));
        my $foo3comment = match($foo3, qq(foo\n));
        my $foo3bol = match($foo3comment, qq(# comment \n));

        is_deeply [strip s_b_comment($foo3comment)],
            [strip $foo3bol, qq(# comment \n)], spec;

    it 'should not match non-comment-sharp.';

        my $foo4 = derivs(qq(foo#sharp \nbar\n));
        my $foo4sharp = match($foo4, qq(foo));

        is_deeply [s_b_comment($foo4sharp)], [], spec;

    it 'should match s-comment end file.';

        my $foo5 = derivs(qq(foo # comment));
        my $foo5comment = match($foo5, q(foo));
        my $foo5eof = match($foo5comment, q( # comment));
        
        is_deeply [strip s_b_comment($foo5comment)],
            [strip $foo5eof, q( # comment)], spec;

    it 'should match l-comment end file.';

        my $foo6 = derivs(qq(foo\n# comment));
        my $foo6comment = match($foo6, qq(foo\n));
        my $foo6eof = match($foo6comment, q(# comment));
        
        is_deeply [strip s_b_comment($foo6comment)],
            [strip $foo6eof, q(# comment)], spec;
}

{
    describe 'Comment Lines';

    it 'should match comment lines.';

        my $exam6_10 = derivs(
              qq(  # Comment\n)
            . qq(   \n)
            . qq(\n)
            . qq(---\n)
        );
        my $exam6_10bol = match($exam6_10, qq(  # Comment\n   \n\n));
        
        is_deeply [strip s_l_comments($exam6_10)],
            [strip $exam6_10bol, qq(  # Comment\n   \n\n)], spec;

    it 'should match comment and line comments.';

        my $foo1 = derivs(qq(- # comment\n# comment \n\n foo\n));
        my $foo1comment = match($foo1, '-');
        my $foo1bol = match($foo1comment, qq( # comment\n# comment \n\n));
        
        is_deeply [strip s_l_comments($foo1comment)],
            [strip $foo1bol, qq( # comment\n# comment \n\n)], spec;

    it 'should match line comments.';

        my $foo1comment2 = match($foo1, qq(- # comment\n));
        
        is_deeply [strip s_l_comments($foo1comment2)],
            [strip $foo1bol, qq(# comment \n\n)], spec;

    it 'should match blank line and comments.';

        my $foo2 = derivs(qq(\n\n# comment\n# comment \n\n - foo\n));
        my $foo2bol = match($foo2, qq(\n\n# comment\n# comment \n\n));

        is_deeply [strip s_l_comments($foo2)],
            [strip $foo2bol, qq(\n\n# comment\n# comment \n\n)], spec;

    it 'should match s-b-comment end file.';

        my $foo3 = derivs(qq(- # comment\n# comment \n\n # foo));
        my $foo3comment1 = match($foo3, '-');
        my $foo3comment2 = match($foo3, qq(- # comment\n));
        my $foo3comment3 = match($foo3, qq(- # comment\n# comment \n\n));
        my $foo3eof = match($foo3, qq(- # comment\n# comment \n\n # foo));

        is_deeply [strip s_l_comments($foo3comment1)],
            [strip $foo3eof, qq( # comment\n# comment \n\n # foo)], spec;

    it 'should match l-comment end file.';

        is_deeply [strip s_l_comments($foo3comment2)],
            [strip $foo3eof, qq(# comment \n\n # foo)], spec;

    it 'should match comment end file.';

        is_deeply [strip s_l_comments($foo3comment3)],
            [strip $foo3eof, qq( # foo)], spec;
}

{
    describe 'Separate';

        my $exam6_12 = derivs(
              qq({ first: Sammy, last: Sosa }:\n)
            . qq(# Statistics:\n)
            . qq(  hr:  # Home runs\n)
            . qq(     65\n)
            . qq(  avg: # Average\n)
            . qq(   0.278)
        );
        my $e1s1 = match($exam6_12, q({));
        my $e1n1 = match($e1s1, q( ));
        my $e1s2 = match($e1n1, q(first:));
        my $e1n2 = match($e1s2, q( ));
        my $e1s3 = match($e1n2, q(Sammy, last: Sosa }:));
        my $e1n3 = match($e1s3, qq(\n# Statistics:\n  ));
        my $e1s4 = match($e1n3, q(hr:));
        my $e1n4 = match($e1s4, qq(  # Home runs\n     ));
        my $e1s5 = match($e1n4, qq(65\n));
        my $e1n5 = match($e1s5, qq(  ));
        my $e1s6 = match($exam6_12, qq({ first: Sammy, last: Sosa }:\n));
        my $e1n6 = match($e1s6, qq(# Statistics:\n  ));

    it 'should match flow-key separate.';
     
        is_deeply [strip s_separate($e1s1, 0, 'flow-key')],
            [strip $e1n1, q( )], spec;

    it 'should match flow-in separate.';
     
        is_deeply [strip s_separate($e1s2, 0, 'flow-in')],
            [strip $e1n2, q( )], spec;

    it 'should match block-in separate begining a newline.';

        is_deeply [strip s_separate($e1s3, -1, 'block-in')],
            [strip $e1n3, qq(\n# Statistics:\n  )], spec;

    it 'should match block-in separate begining a white space.';

        is_deeply [strip s_separate($e1s4, -1, 'block-in')],
            [strip $e1n4, qq(  # Home runs\n     )], spec;

    it 'should match block-in separate begining a white space.';

        is_deeply [strip s_separate($e1s5, -1, 'block-in')],
            [strip $e1n5, qq(  )], spec;

    it 'should match block-in separate begining of line.';

        is_deeply [strip s_separate($e1s6, -1, 'block-in')],
            [strip $e1n6, qq(# Statistics:\n  )], spec;
}

