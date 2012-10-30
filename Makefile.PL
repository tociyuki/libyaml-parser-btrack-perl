use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'YAML::Parser::Btrack',
    AUTHOR              => 'MIZUTANI Tociyuki <tociyuki@gmail.com>',
    VERSION_FROM        => 'lib/YAML/Parser/Btrack.pm',
    ABSTRACT_FROM       => 'lib/YAML/Parser/Btrack.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);
