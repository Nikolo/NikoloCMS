#!/usr/bin/perl

use strict;
use lib 'lib';
use Utils::nikolo qw(rebuild_module restore generate_bridges);
use Model::Schema;
use Config::JSON;
use utf8;

my $config = Config::JSON->new( 'nikolo.cfg' );
my $db_conf = $config->get( 'db' );

my $schema = Model::Schema->connect( $db_conf->{dsn}, $db_conf->{user}, $db_conf->{password}, $db_conf->{params} );
my $dbh = $schema->storage->dbh;

my @patchs;

while( $_ = shift ){ push @patchs, $_ };
unless( scalar @patchs ){
	while( <STDIN> ){
		chomp;
		push @patchs, $_;
	}
} 

foreach( @patchs ){
	my $patch_name = $config->get( 'path' ).$_;
	die "Patch not found" unless -r $patch_name;
	restore( $patch_name, $dbh );
	
}

my $rs = $schema->resultset('Pages');
my $module_list = [$rs->search( undef, { select => [ 'module_name' ], distinct => 1 } )->all()];
foreach my $mn ( @$module_list ){
    printf "Compile module: %s ".$/, $mn->module_name;
    my $page_list = [$rs->search({ module_name => $mn->module_name }, {select => [ 'title', 'module_name', 'name', 'code', 'template' ]})->all()];
    my $module_pages = {map { $_->create_template( $config->get( 'path' ), $config->get( 'main_block_template' )); { $_->name => {text => $_->code, title => $_->title } }} @$page_list };
    my $res = rebuild_module( $config->get( 'path' ), $mn->module_name, $module_pages );
    printf "Res: %s".$/, $res||"OK";
}
generate_bridges( $dbh, $config->get( 'path' ));
