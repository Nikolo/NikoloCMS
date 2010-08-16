package Model::Schema;

use strict;
use base qw/DBIx::Class::Schema/;

our $VERSION = '0.001';

__PACKAGE__->exception_action( sub { die @_ } );

sub import {
	my $no_load_ns = shift;
	__PACKAGE__->load_namespaces( ) unless $no_load_ns;
}

1;
