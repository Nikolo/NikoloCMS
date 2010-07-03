package Model::Schema::Result::Roles;

use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/Core/ );
__PACKAGE__->table( 'role' );
__PACKAGE__->add_columns( qw/ id user grp / );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->belongs_to( user => 'Model::Schema::Result::Users' );
__PACKAGE__->belongs_to( grp => 'Model::Schema::Result::Groups' );

1;

