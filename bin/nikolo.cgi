#!/usr/bin/perl
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";
use lib "$FindBin::Bin/../../../../lib";

$ENV{PLACK_ENV} = 'production';
$ENV{MOJO_HOME} = '/usr/local/www/NikoloCMS';

eval 'use Mojolicious::Commands; use nikolo; nikolo->start( "psgi" );';

if( $@ ){
    print "Content-type: text/html; charset=utf-8\n\nПроизошла непредвиденная ошибка\n".$@;
}

