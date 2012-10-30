package Test::Behaviour;
use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT = qw(describe it spec);

my($subject, $statement);

sub describe { $subject = $_[0] }
sub it { $statement = join q( ), $subject, @_ }
sub spec { $statement }

1;

