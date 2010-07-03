package Model::Schema::Result::Pages;

use strict;
use base qw/DBIx::Class/;

__PACKAGE__->load_components( qw/Core/ );
__PACKAGE__->table( 'pages' );
__PACKAGE__->add_columns( qw/ id name title template module_name code menu_pos menu_name flags bridge_pos/ );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->has_many( acls => 'Model::Schema::Result::ACLs', 'page' );
__PACKAGE__->many_to_many( groups => 'acls', 'grp' );

use Utils::nikolo qw( check_template write_file );

sub link {
	my $self = shift;
	return '/'.$self->module_name.'/'.$self->name;
}
sub flag_list {
	return { 
		2**0 => 'openaccess',
	}
}

sub extract_flags {
	my $self = shift;
	my $flist = $self->flag_list;
	return [map {{ id => $_, name => $flist->{$_}, isset => $self->flags() & $_}} keys %$flist];
}
sub path {
	my $self = shift;
	return "/".$self->name.".html.tt";
}

sub create_template {
	my $self = shift;
	my $path = shift; # path to file
	my $tmpl_path = shift; # path to dir where are included template
	return unless $self->template;
	return check_template( $tmpl_path, \$self->template )||write_file( $path.'templates/'.$self->module_name.$self->path, $self->template );
}

1;
