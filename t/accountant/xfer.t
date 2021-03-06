use Carp::Assert;
use Moonpig::Util qw(dollars);
use Test::More;
use Test::Routine;
use Test::Routine::Util;
use Try::Tiny;

use t::lib::TestEnv;

use Moonpig::Test::Factory qw(build);

test "basics of transfer" => sub {
  my ($self) = @_;
  plan tests => 4;

  my $amount = dollars(100);

  my $stuff = build(c => { template => 'dummy',
                           bank => $amount,
                         });
  my ($ledger, $consumer) = @{$stuff}{qw(ledger c)};

  is(
    $consumer->unapplied_amount,
    $amount,
    "we start with M $amount remaining, too",
  );

  assert($amount > 5000, 'we have at least M 5000 in the bank');

  my @xfers;

  subtest "initial transfer" => sub {
    plan tests => 3;

    push @xfers, $ledger->transfer({
      amount   => 5000,
      from   => $consumer,
      to     => $ledger->current_journal,
    });

    is(@xfers, 1, "we made a transfer");
    is($xfers[0]->type, 'transfer', "the 1st transfer");

    is(
      $consumer->unapplied_amount,
      $amount - 5000,
      "the transfer has affected the apparent remaining amount",
    );
  };

  subtest "transfer down to zero" => sub {
    plan tests => 3;

    push @xfers, $ledger->transfer({
      amount => $amount - 5000,
      from => $consumer,
      to   => $ledger->current_journal,
    });

    is(@xfers, 2, "we made a transfer");
    is($xfers[1]->type, 'transfer', "the 2nd transfer");

    is(
      $consumer->unapplied_amount,
      0,
      "we've got M 0 left in funds",
    );
  };

  subtest "transfer out of an empty bank" => sub {
    plan tests => 4;

    my $err;
    my $ok = try {
      push @xfers, $ledger->transfer({
        amount => 1,
        from => $consumer,
        to   => $ledger->current_journal,
      });
      1;
    } catch {
      $err = $_;
      return;
    };

    ok(! $ok, "we couldn't transfer anything from an empty consumer");
    like($err, qr{Refusing overdraft transfer}, "got the right error");
    is($consumer->unapplied_amount, 0, "still have M 0 in consumer");
    is(@xfers, 2, "the new transfer was never registered");
  };
};

test "multiple transfer types" => sub {
  my ($self) = @_;
  plan tests => 3;
  my $stuff = build(c => { template => 'dummy',
                           bank => dollars(100),
                         });
  my ($ledger, $consumer) = @{$stuff}{qw(ledger c)};
  my $amt = $consumer->unapplied_amount;

  my $h = $ledger->create_transfer({
    type   => 'hold',
    from   => $consumer,
    to     => $ledger->current_journal,
    amount => dollars(1),
  });

  is($consumer->unapplied_amount, $amt - dollars(1), "hold for \$1");

  my $t = $ledger->create_transfer({
    type   => 'transfer',
    to     => $ledger->current_journal,
    from   => $consumer,
    amount => dollars(2),
   });
  is($consumer->unapplied_amount, $amt - dollars(3), "transfer of \$2");

  $h->delete();
  is($consumer->unapplied_amount, $amt - dollars(2), "deleted hold");
};

test "ledger->transfer" => sub {
  my ($self) = @_;
  plan tests => 6;

  my $stuff = build(c => { template => 'dummy',
                           bank => dollars(100),
                         });
  my ($ledger, $consumer) = @{$stuff}{qw(ledger c)};

    for my $type (qw(transfer cashout DEFAULT)) {
        my $err;
        my $t = try {
           $ledger->transfer({
               amount => 1,
               from => $consumer,
               to   => $ledger->current_journal,
               $type eq "DEFAULT" ? () : (type => $type),
           });
        } catch {
            $err = $_;
            return;
        };
        if ($type eq "DEFAULT" || $type eq "transfer") {
            ok($t);
            is($t->type, "transfer");
        } else {
            ok(! $t);
            like($err, qr/\S+/);
        }
    }
};

run_me;
done_testing;
