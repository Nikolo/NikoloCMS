package Model::Schema;

use strict;
use base qw/DBIx::Class::Schema/;

our $VERSION = '0.001';

__PACKAGE__->exception_action( sub { die @_ } );
__PACKAGE__->load_namespaces( );

1;
