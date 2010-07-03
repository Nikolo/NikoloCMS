package Model::Schema::Result::Session;
use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/Core/ );
__PACKAGE__->table( 'session' );
__PACKAGE__->add_columns( qw/ sid data expires/ );
__PACKAGE__->set_primary_key( 'sid' );

1;
