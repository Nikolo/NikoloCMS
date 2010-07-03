package Utils::nikolo;

use strict;
use Exporter 'import';
use Template;
use Encode qw(encode decode);

our @EXPORT_OK = qw( write_file check_template rebuild_module _backup restore);

sub write_file {
	my $path = shift;
	my $text = shift;
	my $err;
	my $dir = $path;
	$dir =~ s{/[^/]+$}{};
	mkdir( $dir );
	if( open my $FH, "> ".$path ){
		printf $FH "%s\n", encode( 'utf-8', $text );
		close $FH;
	}
	else {
		$err = $!." (file ".$path.")";
	}
	return $err;
}

sub check_template {
	my $path = shift;
    my $tmpl = shift;
	return 0 unless $$tmpl;
    my $tt = Template->new({ ABSOLUTE => 1, POST_CHOMP => 1, ENCODING => 'utf8', INCLUDE_PATH => $path });
	eval {
		my $output;
		my $err;
		$tt->process( $tmpl, {self => {}}, \$output ) || die $tt->error();
	};
    return $@ ? $@ : 0;
}

sub check_code {
	my $func_name = shift;
	my $code = shift;
	eval "sub $func_name { $code }";
	return $@ ? $@ : 0; 
}

my @std_pack = qw(strict warnings utf8 Utils::nikolo);

sub rebuild_module {
	my $path = shift;
	my $module_name = shift;
	my $funcs = shift;
	my $err;
	foreach ( keys %$funcs ){
#warn $_." <==> ".$funcs->{$_};
		return "Error while compile func ".$_.": ".$err if $err = check_code( $_, $funcs->{$_} );
	}

	if( open my $FH, "> ".$path."lib/nikolo/".ucfirst($module_name).".pm" ){
		printf $FH "package nikolo::%s;$/%s".$/, ucfirst($module_name), join( $/, map { "use $_;" } @std_pack );
		printf $FH "use base 'Mojolicious::Controller';".$/;
		foreach( keys %$funcs ){
			$funcs->{$_}->{title} =~ s/"/&quot;/g; #"
			next unless $funcs->{$_}->{title} || $funcs->{$_}->{text};
			my $title = '$_[0]->stash->{title} = "'.$funcs->{$_}->{title}.'";';
			printf $FH "sub %s {$/%s$/%s$/}".$/.$/, $_, encode( 'utf-8', $title ), encode( 'utf-8', $funcs->{$_}->{text} );
		}
		printf $FH "1;".$/;
		close $FH;
	}
	else {
		$err = $!." (file ".$path."lib/nikolo/".$module_name.".pm)";
	}

	return $err;
	
}

sub _backup {
	my $srcs = shift;
	my $file = shift;
	my $dbh = shift;
	my $pkg;
	my $sql;
	my @ignore_data = qw( session );
	open my $BACKUP, "> $file";
	foreach ( @$srcs ){
		$pkg = 'Model::Schema::Result::'.$_;
		$sql = 'show create table '.$pkg->table();
		printf $BACKUP "DROP TABLE %s;;\n\n", $pkg->table();
		printf $BACKUP "%s;;\n\n", encode( 'utf-8', [$dbh->selectrow_array( $sql )]->[1]);
		next if grep {$_ eq $pkg->table()} @ignore_data;
		$sql = 'select * from '.$pkg->table();
		foreach(  @{$dbh->selectall_arrayref( $sql )}){
			printf $BACKUP "insert into %s values( %s );;\n\n", encode( 'utf-8', $pkg->table()), encode( 'utf-8', join( ',', map {$_ =~ s/'/\\'/gm; $_ ? "'".$_."'" : 'NULL'} @$_));
		}
	}
	close $BACKUP;
	return ;
}

sub restore {
	my $file = shift;
	my $dbh = shift;
	my $sql;
	open my $RESTORE, "< ".$file;
	while( <$RESTORE> ){
		$sql .= $_;
	}	
	close $RESTORE;
	$dbh->do( $_ ) for grep {$_ !~ /^\s*$/} split /;;\n\n/mg, $sql;
	return ;
}

sub date(;$) {
	my $date = shift || time();
	my ($ss,$mm,$hh,$d,$m,$y) = localtime($date);
	return sprintf "%04u-%02u-%02u %02u:%02u:%02u",$y+1900,$m+1,$d,$hh,$mm,$ss;
}

1;