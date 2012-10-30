use strict;
use warnings;
use Carp;
use Test::More;
use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 4;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*l_yaml_stream = \&YAML::Parser::Btrack::l_yaml_stream;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'Document';

    it 'should match example 9.2.';

        my $s1 = derivs(
              qq(%YAML 1.2\n)
            . qq(---\n)
            . qq(Document\n)
            . qq(... # Suffix\n),
        );
        my $s1end = match($s1,
              qq(%YAML 1.2\n)
            . qq(---\n)
            . qq(Document\n)
            . qq(... # Suffix\n),
        );

        is_deeply [strip l_yaml_stream($s1)],
            [
                strip $s1end,
                ['l-yaml-stream',
                    ['l-directive-document',
                        ['ns-yaml-directive', 'YAML', '1.2'],
                        ['ns-plain', 'Document'],
                    ],
                ],
            ], spec;

    it 'should match example 9.3.';

        my $s2 = derivs(
              qq(Bare\n)
            . qq(document\n)
            . qq(...\n)
            . qq(# No document\n)
            . qq(...\n)
            . qq(|\n)
            . qq(%!PS-Adobe-2.0 # Not the first line\n)
        );
        my $s2end = match($s2,
              qq(Bare\n)
            . qq(document\n)
            . qq(...\n)
            . qq(# No document\n)
            . qq(...\n)
            . qq(|\n)
            . qq(%!PS-Adobe-2.0 # Not the first line\n)
        );

        is_deeply [strip l_yaml_stream($s2)],
            [
                strip $s2end,
                ['l-yaml-stream',
                    ['l-bare-document',
                        ['ns-plain', 'Bare document'], ],
                    ['l-bare-document',
                        ['c-l+literal', qq(%!PS-Adobe-2.0 # Not the first line\n)], ],
                ],
            ], spec;

    it 'should match example 9.4.';

        my $s3 = derivs(
              qq(---\n)
            . qq({ matches\n)
            . qq(% : 20 }\n)
            . qq(...\n)
            . qq(---\n)
            . qq(# Empty\n)
            . qq(...\n)
        );
        my $s3end = match($s3,
              qq(---\n)
            . qq({ matches\n)
            . qq(% : 20 }\n)
            . qq(...\n)
            . qq(---\n)
            . qq(# Empty\n)
            . qq(...\n)
        );

        is_deeply [strip l_yaml_stream($s3)],
            [
                strip $s3end,
                ['l-yaml-stream',
                    ['l-explicit-document',
                        ['c-flow-mapping',
                            ['ns-plain', 'matches %'], ['ns-plain', 20], ],
                    ],
                    ['l-explicit-document',
                        ['e-scalar'],
                    ],
                ],
            ], spec;

    it 'should match example 9.5.';

        my $s4 = derivs(
              qq(%YAML 1.2\n)
            . qq(--- |\n)
            . qq(%!PS-Adobe-2.0\n)
            . qq(...\n)
            . qq(%YAML 1.2\n)
            . qq(---\n)
            . qq(# Empty\n)
            . qq(...\n)
        );
        my $s4end = match($s4, 
              qq(%YAML 1.2\n)
            . qq(--- |\n)
            . qq(%!PS-Adobe-2.0\n)
            . qq(...\n)
            . qq(%YAML 1.2\n)
            . qq(---\n)
            . qq(# Empty\n)
            . qq(...\n)
        );

        is_deeply [strip l_yaml_stream($s4)],
            [
                strip $s4end,
                ['l-yaml-stream',
                    ['l-directive-document',
                        ['ns-yaml-directive', 'YAML', '1.2'],
                        ['c-l+literal', qq(%!PS-Adobe-2.0\n)],
                    ],
                    ['l-directive-document',
                        ['ns-yaml-directive', 'YAML', '1.2'],
                        ['e-scalar'],
                    ],
                ],
            ], spec;
}

