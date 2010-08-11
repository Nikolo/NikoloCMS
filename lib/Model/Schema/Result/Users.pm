package Model::Schema::Result::Users;
use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/Core/ );
__PACKAGE__->table( 'users' );
__PACKAGE__->add_columns( qw/ id login password email first_name last_name middle_name phone adress city comment activationid/ );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->has_many( roles => 'Model::Schema::Result::Roles', 'user' );
__PACKAGE__->many_to_many( groups => 'roles', 'grp' );

1;

