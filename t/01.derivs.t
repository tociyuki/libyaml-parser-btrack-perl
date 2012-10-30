use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 13;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;
*end_of_file = \&YAML::Parser::Btrack::end_of_file;

{
    describe 'Derivs';

        my $input = "- a # c \n- d";
        my $derivs = derivs(\$input);

    it 'should be an arrayref.';

        is ref $derivs, 'ARRAY', spec;

    it 'should package scalar ref. and integer.';

        is_deeply $derivs, [\$input, 0], spec;

    it 'should pass input scalar ref.';

        is_deeply derivs($derivs, 1), [$derivs->[0], 1], spec;

    it 'should match regexp.';

        is_deeply [match($derivs, qr/-/msx)], [derivs($derivs, 1)], spec;

    it 'should match again from same location.';

        is_deeply [match($derivs, qr/-[ ]+/msx)], [derivs($derivs, 2)], spec;

    it 'should match again again from same location.';

        is_deeply [match($derivs, qr/-[ ]+\w/msx)], [derivs($derivs, 3)], spec;

    it 'should match from its location.';

        is_deeply [
            match(derivs($derivs, 3), qr/[ ]+\#[^\n]*\n/msx),
        ], [
            derivs($derivs, 9),
        ], spec;

    it 'should capture from matching result.';

        is_deeply [
            match($derivs, qr/([ ]*-)[ ](\w+)/msx),
        ], [
            derivs($derivs, 3), q(-), q(a)
        ], spec;

    it 'should return empty list to fail match.';

        is_deeply [match($derivs, qr/([ ]*:)/msx)], [], spec;

    it 'should match with string.';

        is_deeply [match($derivs, q(-))], [derivs($derivs, 1), q(-)], spec;

    it 'should not match end_of_file at pos==0.';

        is_deeply [end_of_file(derivs($derivs, 0))], [], spec;

    it 'should not match end_of_file at pos==8.';

        is_deeply [end_of_file(derivs($derivs, 8))], [], spec;

    it 'should match end_of_file at pos==12.';

        is_deeply [end_of_file(derivs($derivs, 12))],
                  [derivs($derivs, 12), q()], spec;
}

