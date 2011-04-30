package Utils::Mailer;

use MIME::Lite;
use Template;
use strict;

sub send_email {
    my $pkg = shift;
    my $params = shift;
    for( qw/from to tname/ ){
    	die $_." is empty" unless $params->{$_};
    }
    
	my $tt = Template->new( { ABSOLUTE => 1, POST_CHOMP => 1, ENCODING => 'utf8', %{$params->{tt_param}||{}} } );
    $params->{stash}->{NEED_TEXT} = 0;
    $params->{stash}->{NEED_SUBJECT} = 1;
	$tt->process( $params->{tname}, { stash => $params->{stash} }, \$params->{subject} ) || die( $tt->error );
    $params->{stash}->{NEED_TEXT} = 1;
    $params->{stash}->{NEED_SUBJECT} = 0;
	$tt->process( $params->{tname}, { stash => $params->{stash} }, \$params->{text} ) || die( $tt->error );

    my $email = MIME::Lite->new(
        From        => $params->{from},
        To          => $params->{to},
        CC          => $params->{cc},
        BCC         => $params->{bcc},
        Subject     => $params->{subject},
        Data        => $params->{text},
        Type        => $params->{contenttype}||'text/html',
        Encoding    => 'base64',
    );
    $email->attr("content-type.charset" => $params->{charset}||'utf8' );
    foreach ( @{$params->{attachments}} ){
        $email->attach(
            Type        => $_->{type},
            Path        => $_->{path},
            Filename    => $_->{filename}||$_->{path},
            Disposition => 'attachment'
        );
    }
    eval {
        $email->send( "sendmail",
            Sendmail => "/usr/sbin/sendmail",
            SetSender => 0,
            FromSender => $params->{from}
        );
    };
    return undef;
}

1;
