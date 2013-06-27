package Ceres::Rcvr;

=head1 NAME

Ceres::Rcvr - Process pulse from sender.

=cut
use strict;
use warnings;

use Carp;
use threads;
use IO::Socket;
use Thread::Queue;

use Ceres::DBI::Index;

use constant MAXBUF => 65;

sub new 
{
    my ( $class, %self ) = splice @_;

=head1 CONFIGURATION

=head3 port

UDP port to listen on

=head3 dbpath

database path

=cut
    map { $self{$_} || confess "$_ not defined" } qw( port dbpath );

    confess "Cannot create socket: $@" unless my $sock =
        IO::Socket::INET->new( LocalPort => $self{port}, Proto => 'udp' );

    my $db = Ceres::DBI::Index->new( $self{dbpath} || $self{db} );
    my $queue = Thread::Queue->new();
    my %host;

    threads::async
    {
        while ( $sock->recv( my $msg, MAXBUF ) )
        {
            $queue->enqueue( $1, $2, $sock->peername )
                if $msg =~ /^([0-9a-f]{32}):([0-9a-f]{32})$/;
        }
    }->detach;

    while ( my ( $key, $md5, $peer ) = $queue->dequeue( 3 ) )
    {
        $db->update( $host{$peer}, $key, $md5 ) if $host{$peer} ||=
            gethostbyaddr( ( sockaddr_in $peer )[1], AF_INET );
    }
}

1;
