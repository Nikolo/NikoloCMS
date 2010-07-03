package Model::Profiler;
use strict;

use base 'DBIx::Class::Storage::Statistics';

use Time::HiRes qw(time);
use Mojo::Log;

my $start;

sub query_start {
    my $self = shift();
    my $sql = shift();
    my @params = @_;
	my $log = Mojo::Log->new;
    $self->print("Executing $sql: ".join(', ', @params)."\n");
    $start = time();
}

sub query_end {
    my $self = shift();
    my $sql = shift();
    my @params = @_;

    my $elapsed = sprintf("%0.4f", time() - $start);
    $self->print("Execution took $elapsed seconds.\n");
    $start = undef;
}

1;