package Model::Schema::Result::Groups;
use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/Core/ );
__PACKAGE__->table( 'groups' );
__PACKAGE__->add_columns( qw/ id name description / );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->has_many( roles => 'Model::Schema::Result::Roles', 'grp' );
__PACKAGE__->many_to_many( users => 'Roles', 'user' );

1;
