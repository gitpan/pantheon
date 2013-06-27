package MIO::TCP;

=head1 NANME

MIO::TCP - Make multiple TCP connections in parallel.

=head1 SYNOPSIS
 
 use MIO::TCP;

 my $mtcp = MIO::TCP->new( qw( host1:port1 host1:port2 ... ) );
 my $result = $mtcp->run( max => 128, log => \*STDERR, timeout => 300 );

 my $mesg = $result->{mesg};
 my $error = $result->{error};

=cut
use strict;
use warnings;

use Carp;
use Fcntl;
use Socket;
use File::Spec;
use Time::HiRes qw( time );
use IO::Poll 0.04 qw( POLLIN POLLHUP POLLOUT );

$| ++;
$/ = undef;

use constant { MAXBUF => 4096, PERIOD => 0.1 };

our %RUN = ( max => 128, timeout => 300, log => \*STDERR );

sub new
{
    my ( $class, %self, %addr ) = shift;

    for my $node ( @_ )
    {
        carp "duplicate addr: $node" if $self{$node};

        my $error = "invalid addr $node"; 
        my ( $type, $addr ) = PF_INET;

        if ( my ( $host, $port ) = $node =~ /^([^:]+):(\d+)$/o )
        {
            confess "$error: invalid port" if $port > 65535;
            confess "$error: invalid host" unless
                $addr{$host} ||= inet_aton $host;
            confess $error unless $addr = sockaddr_in( $port, $addr{$host} );
        }
        else
        {
            $type = PF_UNIX;
            confess "$error: invalid unix domain socket" unless
                File::Spec->file_name_is_absolute( $node )
                    && ( $addr = sockaddr_un( $node ) );
        }

        $self{$node} = [ $type, $addr ];
    }

    bless \%self, ref $class || $class;
}

=head1 METHODS

=head3 run( %param )

Make TCP connections in parallel.
The following parameters may be defined in I<%param>:

 max: ( default 128 ) number of connections in parallel.
 log: ( default STDERR ) a handle to report progress.
 timeout: ( default 300 ) number of seconds allotted for each connection.

Returns HASH of HASH of nodes. First level is indexed by type
( I<mesg> or I<error> ). Second level is indexed by message.

=cut
sub run
{
    my $self = shift;

    confess "poll: $!" unless my $poll = IO::Poll->new();

    my %run = ( %RUN, @_ );
    my ( %result, %buffer, %count );
    my ( $log, $max, $timeout ) = @run{ qw( log max timeout ) };
    my $input = -t STDIN ? '' : <STDIN>;
    my @node = keys %$self;

    for ( my $time = time; @node || $poll->handles; )
    {
        if ( time - $time > $timeout ) ## timeout
        {
            for my $sock ( keys %count )
            {
                $poll->remove( $sock );
                shutdown $sock, 2;
                push @{ $result{error}{timeout} }, delete $count{$sock};
            }

            print $log "timeout!\n";
            last;
        }

        while ( @node && keys %count < $max )
        {
            my $node = shift @node;
            my ( $type, $addr, $sock ) = @{ $self->{$node} };

            unless ( socket $sock, $type, SOCK_STREAM, 0 )
            {
                push @{ $result{error}{ "socket: $!" } }, $node;
                next;
            }

            fcntl $sock, F_SETFL, O_NONBLOCK | fcntl $sock, F_GETFL, 0;
            connect $sock, $addr;

            $poll->mask( $sock => POLLIN | POLLOUT );
            $count{$sock} = $node;
            print $log "$node started.\n";
        }

        $poll->poll( PERIOD );

        for my $sock ( $poll->handles( POLLIN ) ) ## read
        {
            sysread $sock, my $buffer, MAXBUF;
            $buffer{$sock} .= $buffer;
        }

        for my $sock ( $poll->handles( POLLOUT ) ) ## write
        {
            syswrite $sock, $input;
            $poll->mask( $sock, $poll->mask( $sock ) & ~POLLOUT );
            shutdown $sock, 1;
        }

        for my $sock ( $poll->handles( POLLHUP ) ) ## done
        {
            my $node = delete $count{$sock};

            push @{ $result{mesg}{ delete $buffer{$sock} } }, $node
                if length $buffer{$sock};

            $poll->remove( $sock );
            shutdown $sock, 0;
            print $log "$node done.\n";
        }
    }

    push @{ $result{error}{'not run'} }, @node if @node;
    return wantarray ? %result : \%result;
}

1;
