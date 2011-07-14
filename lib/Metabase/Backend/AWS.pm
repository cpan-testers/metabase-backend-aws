use 5.006;
use strict;
use warnings;

package Metabase::Backend::AWS;
# VERSION

use Moose::Role;
use namespace::autoclean;

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

1;

# ABSTRACT: Metabase backend implemented using Amazon Web Services
# COPYRIGHT

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

XXX consolidate synopses from modules

=head1 DESCRIPTION

This distribution provides a backend for L<Metabase> using Amazon Web Services.
There are two modules included, L<Metabase::Index::SimpleDB> and
L<Metabase::Archive::S3>.  They can be used separately or together (see
L<Metabase::Librarian> for details).

The L<Metabase::Backend::AWX> module is a L<Moose::Role> that provides
common attributes and private helpers and is not intended to be used directly.

Common attributes are described further below.

=attr access_key_id

An AWS Access Key ID

=attr secret_access_key

An AWS Secret Access Key matching the Access Key ID

=cut

