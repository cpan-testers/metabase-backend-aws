use 5.006;
use strict;
use warnings;

package Metabase::Archive::S3;
# ABSTRACT: Metabase storage using Amazon S3

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Path::Class;

use Metabase::Fact;
use Carp       ();
use Data::GUID ();
use Data::Stream::Bulk::Filter 0.08;
use JSON 2 ();
use Net::Amazon::S3;
use Path::Class ();
use Compress::Zlib 2 qw(compress uncompress);

with 'Metabase::Archive';

# Prefix string must have a trailing slash but not leading slash
subtype 'PrefixStr'
  => as 'Str'
  => where { $_ =~ m{^\w} && $_ =~ m{/$} };

coerce 'PrefixStr'
  => from 'Str' => via { s{/$}{}; s{^/}{}; $_ . "/" };

has 'access_key_id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'secret_access_key' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'bucket' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'prefix' => (
    is       => 'ro',
    isa      => 'PrefixStr',
    required => 1,
    coerce   => 1,
);

has 'compressed' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has 's3_bucket' => (
    is       => 'ro',
    isa      => 'Net::Amazon::S3::Client::Bucket',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        my $s3   = Net::Amazon::S3->new(
            aws_access_key_id     => $self->access_key_id,
            aws_secret_access_key => $self->secret_access_key,
            retry                 => 1,
        );
        my $client = Net::Amazon::S3::Client->new( s3 => $s3 );
        my $method = (grep { $_ eq $self->bucket } $client->buckets) ? 'bucket' : 'create_bucket';
        return $client->$method( name => $self->bucket );
    }
);

has '_json' => (
  is => 'ro',
  required => 1,
  lazy => 1,
  default => sub { JSON->new->ascii },
);

# given fact, store it and return guid;
sub store {
    my ( $self, $fact_struct ) = @_;
    my $guid = $fact_struct->{metadata}{core}{guid};
    my $type = $fact_struct->{metadata}{core}{type};

    unless ($guid) {
        Carp::confess "Can't store: no GUID set for fact\n";
    }

    my $json = $self->_json->encode($fact_struct);

    if ( $self->compressed ) {
        $json = compress($json);
    }

    my $s3_object = $self->s3_bucket->object(
        key          => $self->prefix . lc $guid,
#        acl_short    => 'public-read',
        content_type => 'application/json',
    );
    $s3_object->put($json);

    return $guid;
}

# given guid, retrieve it and return it
# type is directory path
# class isa Metabase::Fact::Subclass
sub extract {
    my ( $self, $guid ) = @_;

    my $s3_object = $self->s3_bucket->object( key => $self->prefix . lc $guid );
    return $self->_extract_struct( $s3_object );
}

sub _extract_struct {
  my ( $self, $s3_object ) = @_;

  my $json = $s3_object->get;
  if ( $self->compressed ) {
    $json = uncompress($json);
  }
  my $struct  = $self->_json->decode($json);
  return $struct;
}

# DO NOT lc() GUID
sub delete {
    my ( $self, $guid ) = @_;

    my $s3_object = $self->s3_bucket->object( key => $self->prefix . $guid );
    $s3_object->delete;
}

sub iterator {
  my ($self) = @_;
  return Data::Stream::Bulk::Filter->new(
    stream => $self->s3_bucket->list( { prefix => $self->prefix } ),
    filter => sub {
      return [ map { $self->_extract_struct( $_ ) } @{ $_[0] } ];
    },
  );
}

1;

__END__

=for Pod::Coverage::TrustPod store extract delete iterator

=head1 SYNOPSIS

  require Metabase::Archive::S3;
  Metabase::Archive::S3->new(
    access_key_id => 'XXX',
    secret_access_key => 'XXX',
    bucket     => 'acme',
    prefix     => 'metabase/',
    compressed => 0,
  );

=head1 DESCRIPTION

Store facts in Amazon S3.

=head1 USAGE

See L<Metabase::Archive> and L<Metabase::Librarian>.

TODO: document optional C<compressed> option (default 1) and
C<schema> option (sensible default provided).

=head1 BUGS

Please report any bugs or feature using the CPAN Request Tracker.
Bugs can be submitted through the web interface at
L<http://rt.cpan.org/Dist/Display.html?Queue=Metabase>

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

=head1 COPYRIGHT AND LICENSE

Portions Copyright (c) 2010 by Leon Brocard

Licensed under terms of Perl itself (the "License").
You may not use this file except in compliance with the License.
A copy of the License was distributed with this file or you may obtain a
copy of the License from http://dev.perl.org/licenses/

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut
