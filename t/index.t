use 5.010;
use strict;
use warnings;

# XXX monkeypatching
use Data::Dumper;
use LWP::UserAgent ();
my $orig_request;
BEGIN {
  no warnings 'redefine';
  $orig_request = \&LWP::UserAgent::request;
  *LWP::UserAgent::request = sub {
#    warn "REQUEST " . Dumper($_[1]) . "\n";
    my $response = $orig_request->(@_);
#    warn "RESPONSE " . Dumper($response) . "\n";
    return $response;
  }
}
use Test::More;
use Test::Routine;
use Test::Routine::Util;
use Net::Amazon::Config;
use Metabase::Index::SimpleDB;


local $SIG{INT} = sub { warn "Got SIGINT"; exit 1 };

my $profile_env = "PERL_METABASE_TEST_AWS_PROFILE";
unless ( $ENV{$profile_env} ) {
  plan skip_all => "No \$ENV{$profile_env} provided for testing";
}

has amazon_config => (
  is => 'ro',
  isa => 'Net::Amazon::Config',
  default => sub { Net::Amazon::Config->new },
);

has 'profile' => (
  is      => 'ro',
  isa     => 'Net::Amazon::Config::Profile',
  lazy_build    => 1,
  handles => [ qw/access_key_id secret_access_key/ ],
);
 
has 'test_domain' => (
  is => 'ro',
  isa => 'Str',
  lazy_build => 1,
);

sub _build_test_domain {
  return "org.cpantesters.metabase.test" . int(rand(2**31));
}

sub _build_profile {
  my $self = shift;
  die "No \$ENV{$profile_env}\n" unless $ENV{$profile_env};
  return $self->amazon_config->get_profile( $ENV{$profile_env} );
}

sub _build_index {
  my $self = shift;
  return Metabase::Index::SimpleDB->new(
      access_key_id     => $self->access_key_id,
      secret_access_key => $self->secret_access_key,
      domain            => $self->test_domain,
      consistent        => 1,
  );
}

before clear_index => sub {
  my $self = shift;
  $self->index->simpledb->send_request(
    'DeleteDomain', { DomainName => $self->test_domain }
  );
};

sub DEMOLISH { my $self = shift; $self->clear_index; }

run_tests(
  "Run Index tests on Metabase::Index::SimpleDB",
  ["main", "Metabase::Test::Index"],
);

done_testing;
