#!/usr/bin/perl
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../lib";
use lib "$FindBin::Bin/../../../../lib";

eval 'use Mojolicious::Commands; use nikolo; nikolo->start( "cgi" );';

if( $@ ){
    print "Content-type: text/html\n\n������ �������� ����������\n";
}
