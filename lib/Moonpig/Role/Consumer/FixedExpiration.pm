package Moonpig::Role::Consumer::FixedExpiration;
# ABSTRACT: a consumer that expires automatically on a particular date
use Moose::Role;

use List::AllUtils qw(all first);
use MooseX::Types::Moose qw(Str);
use Moonpig::Types qw(PositiveMillicents Time);

with(
  'Moonpig::Role::Consumer',
  'Moonpig::Role::Consumer::PredictsExpiration',
);

use namespace::autoclean;

use Moonpig::Behavior::EventHandlers;

sub charge {
  my ($self) = @_;
  return if $self->is_expired;
  $self->expire if $self->expiration_date <= Moonpig->env->now;
}

sub remaining_life {
  my ($self, $when) = @_;
  $when ||= Moonpig->env->now;
  my $diff = $self->expiration_date - $when;
  return $diff < 0 ? 0 : $diff;
}

sub estimated_lifetime {
  my ($self) = @_;
  return $self->expiration_date - $self->activated_at;
}

sub _replacement_chain_expiration_date {
  my ($self, $arg) = @_;

  my @chain = ($self, $self->replacement_chain);

  my $exp_date = Moonpig::Env->now;

  CONSUMER: for my $i (0 .. $#chain) {
    my $this = $chain[$i];

    if ($this->does('Moonpig::Role::Consumer::FixedExpiration')) {
      my $this_exp_date = $this->expiration_date;
      if ($this_exp_date > $exp_date) {
        $exp_date = $this_exp_date;
      }
    } elsif ($this->does('Moonpig::Role::Consumer::ByTime')) {
      my @rest_of_chain = @chain[ $i .. $#chain ];

      unless (all { $_->does('Moonpig::Role::Consumer::ByTime') } @rest_of_chain) {
        Moonpig::X->throw("replacement chain can't predict expiration date");
      }

      $exp_date = $exp_date + (sumof {
        $_->_estimated_remaining_funded_lifetime({
          amount => $_->expected_funds({
            include_unpaid_charges => $arg->{include_expected_funds},
          }),
          ignore_partial_charge_periods => 1,
        })
      } @rest_of_chain);

      last CONSUMER;
    }

    Moonpig::X->throw("replacement chain can't predict expiration date");
  }

  return $exp_date;
}

sub _estimated_remaining_funded_lifetime {
  my ($self) = @_;

  Moonpig::X->throw("can't compute remaining lifetime on inactive consumer")
    unless $self->is_active;

  return $self->remaining_life;
}

1;
