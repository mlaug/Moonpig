use Test::Routine;
use Test::Routine::Util -all;
use Test::More;
use Test::Fatal;

with(
  't::lib::Factory::Ledger',
);

use Moonpig::Env::Test;

# use Moonpig::Util qw(class days dollars event);

use namespace::autoclean;

use Moonpig::Util qw(class);

class('Ledger');

test "end to end demo" => sub {
  my ($self) = @_;

  my $ledger = $self->test_ledger;

  my $guid = $ledger->guid;

  # XXX: temporary first draft of a route to get the guid
  # /ledger/guid/:GUID/gguid
  my ($resource) = Moonpig->env->route(
    [ 'ledger', 'guid', $guid, 'gguid' ],
  );

  my $result = $resource->resource_request(get => {});

  is($result, $guid, "we can get the ledger's guid by routing to it");
};

run_me;
done_testing;