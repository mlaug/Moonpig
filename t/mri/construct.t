
package main;
use strict;
use warnings;

use Carp qw(confess croak);
use Moonpig::URI;
use Moonpig::Util qw(days);
use Test::More;
use Try::Tiny;

use Moose;
with 't::lib::Factory::Ledger';

my $day = days(1);
plan tests => 5;
is(Moonpig::URI->nothing->construct, undef, "nothing => undef");
ok(Moonpig::URI->new('moonpig://test/consumer/ByTime')
  ->construct({extra => {
    old_age => $day,
    cost_amount => 0,
    ledger => __PACKAGE__->test_ledger(),
    cost_period => $day,
    replacement_mri => Moonpig::URI->nothing(),
   }}),
   "good path Consumer::ByTime");

for my $bad (qw(moonpig://foo
                moonpig://test/bar
                moonpig://test/consumer/ByTime/yobgorgle
              )) {
  my $mri = Moonpig::URI->new($bad) or die "Couldn't make '$bad'";
  try {
    $mri->construct;
  } finally {
    ok(@_, "$bad failed");
  }
}

done_testing;

