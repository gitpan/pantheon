package Vulcan::Phasic;

use warnings;
use strict;
use Carp;
use threads;
use Thread::Queue;
use Time::HiRes qw( time sleep alarm stat );

use Vulcan::Logger;

=head1 SYNOPSIS

 use Vulcan::Phasic;

 my $phase = Vulcan::Phasic->new
 (
     src => \@src, dst => \@dst, quiesce => [],
     code => sub { .. }, weight => sub { return int .. }
 );

 $phase->run
 ( 
     retry => 3, timeout => 100, log => $handle, param => { .. },
 );

=cut
our $MAX = 128;

sub new
{
    my ( $class, %self ) = splice @_;

    $self{weight} ||= sub { 0 };
    $self{quiesce} ||= [];

    for my $name ( qw( code weight ) )
    {
        my $code = $self{$name};
        confess "undefined/invalid $name" unless $code && ref $code eq 'CODE';
    }

    for my $name ( qw( src dst quiesce ) )
    {
        confess "undefined/invalid $name" unless my $node = $self{$name};
        $self{$name} = [ $node ] if ref $node ne 'ARRAY';
    }

    bless \%self, ref $class || $class
}

=head1 METHODS

=head3 run( %param )

The following parameters may be defined in %param.

 timeout : ( default 0 = no timeout ) number of retries.
 retry : ( default 0 = no retry ) number of retries.
 log : ( default STDERR ) file handle for logging.

=cut
sub run
{
    my $self = shift;
    my %run = ( retry => 0, timeout => 0, log => \*STDERR, @_ );

    my ( $retry, $timeout, $log ) = delete @run{ qw( retry timeout log ) };
    my ( $w8, $code ) = @$self{ 'weight', 'code' };

    $log = Vulcan::Logger->new( $log );
    $run{log} = sub { $log->say( @_ ) };

    my %src = map { $_ => &$w8( $_ ) } @{ $self->{src} };
    my %dst = map { $_ => &$w8( $_ ) } grep { ! $src{$_} } @{ $self->{dst} };
    my %quiesce = map { $_ => 1 } @{ $self->{quiesce} };

    my @queue = map { Thread::Queue->new() } 0, 1;
    my ( %busy, %fail );

    for my $i ( 1 .. ( sort { $a <=> $b } 0 + keys %dst, $MAX )[0] )
    {
        threads::async
        {
            my ( $ok, $src, $dst, $info ) = 1;
            eval
            {
                local $SIG{ALRM} = sub { die 'timeout' if $src };

                while ( sleep 1 )
                {
                    next unless $queue[0]->pending();
                    last if ( $src, $dst ) = $queue[0]->dequeue_nb( 2 );
                }

                $info = &$code( $src, $dst, %run );
            };
            if ( $@ ) { $info = $@; $ok = 0 }
            $queue[1]->enqueue( $src, $dst, $ok, $info );
        }
    }

    for ( my $now = time; %dst || %busy; sleep 1 )
    {
        while ( $queue[1]->pending() )
        {
            my ( $src, $dst, $ok, $info ) = $queue[1]->dequeue_nb( 4 );
            @src{ $src, $dst } = delete @busy{ $src, $dst };

            delete $src{$src} if $quiesce{$src};
            delete $dst{$dst} unless $ok || $fail{$dst} ++ < $retry;

            $log->say( "$dst <= $src: $info" );
            $now = time;
        }

        if ( $timeout && time - $now > $timeout )
        {
            map { $_->kill( 'SIGALRM' ) } threads->list();
        }
        elsif ( %src && %dst )
        {
            $queue[0]->enqueue( $self->pick( \%src, \%dst, \%busy ) );
        }
    }

    $self->{fail} = [ grep { $fail{$_} > $retry } keys %fail ];
    map { $_->detach() } threads->list();
    return $self;
}

## select a pair source and destination nodes, with minimal distance.
sub pick
{
    my ( $this, $src, $dst, $busy ) = @_;
    my $d = each %$dst;
    my $w8 = $busy->{$d} = delete $dst->{$d};

    my %dist = map { $_ => abs( $src->{$_} - $w8 ) } keys %$src;
    my ( $s ) = sort { $dist{$a} <=> $dist{$b} } keys %dist;
    $busy->{$s} = delete $src->{$s};
    return $s, $d;
}

1;
