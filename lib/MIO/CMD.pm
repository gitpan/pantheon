package MIO::CMD;

=head1 NAME

MIO::CMD - Run multiple commands in parallel.

=head1 SYNOPSIS
 
 use MIO::CMD;

 my @node = qw( host1 host2 ... );
 my @cmd = qw( ssh {} wc );

 my $mcmd = MIO::CMD->new( map { $_ => \@cmd } @node );
 my $result = $mcmd->run( max => 32, log => \*STDERR, timeout => 300 );

 my $stdout = $result->{stdout};
 my $stderr = $result->{stderr};
 my $error = $result->{error};

=cut
use strict;
use warnings;

use Carp;
use IPC::Open3;
use Time::HiRes qw( time );
use POSIX qw( :sys_wait_h );
use IO::Poll qw( POLLIN POLLHUP POLLOUT );

$| ++;
$/ = undef;

use constant { MAXBUF => 4096, PERIOD => 0.1 };

our %RUN = ( max => 32, timeout => 300, log => \*STDERR );

sub new
{
    my ( $class, %self, %ok ) = splice @_;
    while ( my ( $node, $cmd ) = each %self )
    {
        confess "command undefined for $node" unless $cmd;
        $self{$node} = $ok{$cmd} ||= ref $cmd ? $cmd : [ $cmd ];
    }
    bless \%self, ref $class || $class;
}

=head1 METHODS

=head3 run( %param )

Run commands in parallel.
The following parameters may be defined in I<%param>:

 max: ( default 32 ) number of commands in parallel.
 log: ( default STDERR ) a handle to report progress.
 timeout: ( default 300 ) number of seconds allotted for each command.

Returns HASH of HASH of nodes. First level is indexed by type
( I<stdout>, I<stderr>, or I<error> ). Second level is indexed by message.

=cut
sub run
{
    my $self = shift;

    confess "poll: $!" unless my $poll = IO::Poll->new();

    my %run = ( %RUN, @_ );
    my ( $log, $max, $timeout ) = @run{ qw( log max timeout ) };
    my ( %result, %buffer, %count );
    my $input = -t STDIN ? '' : <STDIN>;
    my @node = keys %$self;
    my %node = map { $_ => {} } qw( stdout stderr );

    for ( my $time = time; @node || $poll->handles; )
    {
        if ( time - $time > $timeout ) ## timeout
        {
            for my $node ( keys %count )
            {
                my ( $pid ) = @{ delete $count{$node} };
                kill 9, $pid;
                waitpid $pid, WNOHANG;
                push @{ $result{error}{timeout} }, $node;
            }

            print $log "timeout!\n";
            last;
        }

        while ( @node && keys %count < $max )
        {
            my $node = shift @node;
            my $cmd = $self->{$node};
            my @io = ( undef, undef, Symbol::gensym );
            my @cmd = map { my $t = $_; $t =~ s/{}/$node/g; $t } @$cmd;
            my $pid = eval { IPC::Open3::open3( @io, @cmd ) };

            if ( $@ )
            {
                push @{ $result{error}{ "open3: $@" } }, $node;
                next;
            }

            $poll->mask( $io[0] => POLLOUT ) if $input;
            $poll->mask( $io[1] => POLLIN );
            $poll->mask( $io[2] => POLLIN );

            $node{ $io[1] } = [ stdout => $node ]; 
            $node{ $io[2] } = [ stderr => $node ]; 

            $count{$node} = [ $pid, 2 ];
            print $log "$node started.\n";
        }

        $poll->poll( PERIOD );

        for my $fh ( $poll->handles( POLLIN ) ) ## stdout/stderr
        {
            sysread $fh, my $buffer, MAXBUF;
            $buffer{$fh} .= $buffer;
        }

        for my $fh ( $poll->handles( POLLOUT ) ) ## stdin
        {
            syswrite $fh, $input;
            $poll->remove( $fh );
            close $fh;
        }

        for my $fh ( $poll->handles( POLLHUP ) ) ## done
        {
            my ( $io, $node ) = @{ delete $node{$fh} };

            push @{ $result{$io}{ delete $buffer{$fh} } }, $node
                if length $buffer{$fh};

            unless ( -- $count{$node}[1] )
            {
                waitpid $count{$node}[0], WNOHANG;
                delete $count{$node};
                print $log "$node done.\n";
            }

            $poll->remove( $fh );
            close $fh;
        }
    }

    push @{ $result{error}{'not run'} }, @node if @node;
    return wantarray ? %result : \%result;
}

1;
