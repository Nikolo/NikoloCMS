package Model::Schema::Result::ACLs;

use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/Core/ );
__PACKAGE__->table( 'acls' );
__PACKAGE__->add_columns( qw/ id page grp / );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->belongs_to( page => 'Model::Schema::Result::Pages' );
__PACKAGE__->belongs_to( grp => 'Model::Schema::Result::Groups' );

1;
