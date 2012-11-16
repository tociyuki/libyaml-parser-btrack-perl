use strict;
use warnings;
use Carp;
use Test::More;
# use Test::Exception;
use YAML::Parser::Btrack;

BEGIN { require 't/behaviour.pm' and Test::Behaviour->import }

plan tests => 17;

*derivs = \&YAML::Parser::Btrack::derivs;
*match = \&YAML::Parser::Btrack::match;

*l_directive = \&YAML::Parser::Btrack::l_directive;
*c_ns_properties = \&YAML::Parser::Btrack::c_ns_properties;

sub strip {
    return () if ! @_;
    my $pos = shift->[1];
    return ($pos, @_);
}

{
    describe 'YAML Directive';

    it 'should match yaml directive.';

        my $yaml1 = derivs(qq(%YAML 1.2\n---\n));
        my $yaml1end = match($yaml1, qq(%YAML 1.2\n));
    
        is_deeply [strip l_directive($yaml1)],
            [strip $yaml1end, ['ns-yaml-directive', 'YAML', '1.2']], spec;

    it 'should match yaml directive with comments.';

        my $yaml2 = derivs(qq(%YAML 1.2 # comment #\n\n# again\n\n---));
        my $yaml2end = match($yaml2, qq(%YAML 1.2 # comment #\n\n# again\n\n));
    
        is_deeply [strip l_directive($yaml2)],
            [strip $yaml2end, ['ns-yaml-directive', 'YAML', '1.2']], spec;

    it 'should not match broken yaml directive.';

        my $yaml3 = derivs(qq(%YAML 1.2 beta\n---));

        is_deeply [l_directive($yaml3)], [], spec;

    it 'should not match broken yaml directive again.';

        my $yaml4 = derivs(qq(%YAML 1.2beta\n---));

        is_deeply [l_directive($yaml4)], [], spec;
}

{
    describe 'TAG Directive';

    it 'should match named tag directive.';
    
        my $tag1 = derivs(qq(%TAG !yaml! tag:yaml.org.2002:\n---\n));
        my $tag1end = match($tag1, qq(%TAG !yaml! tag:yaml.org.2002:\n));
        
        is_deeply [strip l_directive($tag1)], [strip $tag1end,
              ['ns-tag-directive', 'TAG', '!yaml!', 'tag:yaml.org.2002:']], spec;

    it 'should match secondary tag directive.';

        my $tag2 = derivs(qq(%TAG !! tag:example.com,2000:app/\n---\n));
        my $tag2end = match($tag2, qq(%TAG !! tag:example.com,2000:app/\n));
        
        is_deeply [strip l_directive($tag2)], [strip $tag2end,
              ['ns-tag-directive', 'TAG', '!!', 'tag:example.com,2000:app/']], spec;

    it 'should match primary tag directive.';

        my $tag3 = derivs(qq(%TAG ! tag:example.com,2000:/\n---\n));
        my $tag3end = match($tag3, qq(%TAG ! tag:example.com,2000:/\n));
        
        is_deeply [strip l_directive($tag3)], [strip $tag3end,
              ['ns-tag-directive', 'TAG', '!', 'tag:example.com,2000:/']], spec;

    it 'should match tag directive with comments.';

        my $tag4 = derivs(
              qq(%TAG ! tag:example.com,2012:/  # comment #\n)
            . qq(\n# again\n\n)
            . qq(---\n),
        );
        my $tag4end = match($tag4,
              qq(%TAG ! tag:example.com,2012:/  # comment #\n)
            . qq(\n# again\n\n),
        );

        is_deeply [strip l_directive($tag4)], [strip $tag4end,
              ['ns-tag-directive', 'TAG', '!', 'tag:example.com,2012:/']], spec;
}

{
    describe 'TAG Reserved';
    
    it 'should match reserved tag directive.';
    
        my $tag1 = derivs(
              qq(%FOO  bar baz # Should be ignored\n)
            . qq(               # with a warning.\n)
            . qq(--- "foo"\n),
        );
        my $tag1end = match($tag1,
              qq(%FOO  bar baz # Should be ignored\n)
            . qq(               # with a warning.\n)
        );
        
        is_deeply [strip l_directive($tag1)], [strip $tag1end,
              ['ns-reserved-directive', 'FOO', 'bar', 'baz']], spec;
}

{
    describe 'Node Properties';

    it 'should match verbatim tag.';

        my $tag1 = derivs(qq(!<tag:yaml.org,2002:str> foo :\n));
        my $tag1end = match($tag1, qq(!<tag:yaml.org,2002:str>));
    
        is_deeply [strip c_ns_properties($tag1, 0, 'block-in')],
            [
                strip $tag1end,
                ['c-ns-properties',
                    ['c-ns-tag-property', '!<tag:yaml.org,2002:str>'],
                    undef, ],
            ], spec;

    it 'should match verbatim tag also.';

        my $tag2 = derivs(qq(!<!bar> baz\n));
        my $tag2end = match($tag2, qq(!<!bar>));
    
        is_deeply [strip c_ns_properties($tag2, 0, 'block-in')], 
            [
                strip $tag2end, 
                ['c-ns-properties',
                    ['c-ns-tag-property', '!<!bar>'],
                    undef, ],
            ], spec;

    it 'should match shorthand tag.';

        my $tag3 = derivs(qq(!!str bar\n));
        my $tag3end = match($tag3, qq(!!str));
    
        is_deeply [strip c_ns_properties($tag3, 1, 'flow-out')],
            [
                strip $tag3end,
                ['c-ns-properties',
                    ['c-ns-tag-property', '!!str'],
                    undef, ],
            ], spec;

    it 'should match shorthand tag other.';

        my $tag4 = derivs(qq(!e!tag%21 baz\n));
        my $tag4end = match($tag4, qq(!e!tag%21));
    
        is_deeply [strip c_ns_properties($tag4, 1, 'flow-out')],
            [
                strip $tag4end,
                ['c-ns-properties',
                    ['c-ns-tag-property', '!e!tag%21'],
                    undef, ],
            ], spec;

    it 'should match non-specific tag.';

        my $tag5 = derivs(qq(! 12\n));
        my $tag5end = match($tag5, qq(!));
    
        is_deeply [strip c_ns_properties($tag5, 1, 'flow-out')],
            [
                strip $tag5end,
                ['c-ns-properties',
                    ['c-ns-tag-property', '!'],
                    undef, ],
            ], spec;

    it 'should match node anchor.';

        my $anchor6 = derivs(qq(&anchor Value\n));
        my $anchor6end = match($anchor6, qq(&anchor));
    
        is_deeply [strip c_ns_properties($anchor6, 1, 'flow-out')],
            [
                strip $anchor6end,
                ['c-ns-properties',
                    undef,
                    ['c-ns-anchor-property', '&anchor'], ],
            ], spec;

    it 'should match both tag and anchor.';

        my $both7 = derivs(qq(!!str  &a1 "foo":\n));
        my $both7end = match($both7, qq(!!str  &a1));

        is_deeply [strip c_ns_properties($both7, 0, 'block-key')],
            [
                strip $both7end,
                ['c-ns-properties',
                    ['c-ns-tag-property', '!!str'],
                    ['c-ns-anchor-property', '&a1'], ],
            ], spec;

    it 'should match both tag and anchor reversed.';

        my $both8 = derivs(qq(&a1  !!str "foo":\n));
        my $both8end = match($both8, qq(&a1  !!str));
        
        is_deeply [strip c_ns_properties($both8, 1, 'flow-in')],
            [
                strip $both8end,
                ['c-ns-properties',
                    ['c-ns-tag-property', '!!str'],
                    ['c-ns-anchor-property', '&a1'], ],
            ], spec;
}

