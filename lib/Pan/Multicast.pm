package Pan::Multicast;

=head1 NAME

Pan::Multicast - data distribution via multicast

=cut
use strict;
use warnings;
use Carp;

use File::Temp;
use Digest::MD5;
use IO::Socket::Multicast;
use Time::HiRes qw( sleep time );

use constant
{
    MTU => 1500, HEAD => 50, MAXBUF => 4096, REPEAT => 2, NULL => ''
};

=head1 SYNOPSIS

 use Pan::Multicast;
 
 my $mcast = Pan::Multicast->new( addr => '255.0.0.2:8360', iface => 'eth1' );

 ## sender
 $mcast->send            ## default
 ( 
     file => '/foo/baz',
     ttl  => 1,          ## 1
     repeat => 2,        ## 2
     buffer => 4096,     ## MAXBUF
 );

 ## receiver
 $mcast->recv( repo => '/foo/bar' );

=cut
sub new
{
    my ( $class, %param ) = splice @_;
    my $sock = IO::Socket::Multicast
        ->new( LocalAddr => $param{addr}, ReuseAddr => 1 );

    $sock->mcast_loopback( 0 );
    $sock->mcast_if( $param{iface} ) if $param{iface};
    bless \$sock, ref $class || $class;
}

sub send
{
    my ( $self, %param ) = splice @_;
    my $sock = $$self;
    my $file = $param{file} || confess "file not defined";
    my $repeat = $param{repeat} || REPEAT;
    my $bufcnt = $param{buffer} || MAXBUF;
    my $buflen = MTU - HEAD;

    $sock->mcast_ttl( $param{ttl} ) if $param{ttl};
    $file = readlink $file if -l $file;
    $bufcnt = MAXBUF if $bufcnt > MAXBUF;

    confess "$file: not a file" unless -f $file;
    confess "$file: open: $!\n" unless open my $fh => $file;

    my $md5 = Digest::MD5->new()->addfile( $fh )->hexdigest();
    seek $fh, 0, 0; binmode $fh;

    my $send = sub
    {
        my $data = sprintf "%s%014x%04x", $md5, @_[0,1];
        $data .= ${ $_[2] } if @_ > 2;
        map { $sock->send( $data ) } 0 .. $repeat;
    };

    for ( my ( $index, $cont, @buffer ) = ( 0, 1 ); my $time = time; )
    {
        for ( 1 .. $bufcnt )
        {
            my $data;
            push @buffer, ( $cont = read $fh, $data, $buflen ) ? \$data : last;
        }

        map { &$send( $index, $_, shift @buffer ) } 0 .. $#buffer;
        sleep( time - $time );
        &$send( $index ++, $cont ? MAXBUF : MAXBUF + 1 );
    }

    close $fh;
    return $self;
}

sub recv
{
    local $| = 1;

    my ( $self, %param ) = splice @_;
    my $sock = $$self;
    my $repo = $param{repo} || confess "repo not defined";

    $repo = readlink $repo if -l $repo;
    confess "$repo: not a directory" unless -d $repo;

    for ( my %buffer; 1; )
    {
        my $data;

        next unless $sock->recv( $data, MTU );
        next unless my ( $md5, $index, $i ) = substr( $data, 0, HEAD, NULL )
            =~ /^({[0-9a-f]}32)({[0-9a-f]}14)({[0-9a-f]}4)$/;

        $index = hex $index; $i = hex $i;

        my $file = "$repo/$md5"; next if -f $file;
        my $buffer = $buffer{$md5} ||= { $index => [] };

        if ( $i < MAXBUF ) { $buffer->{$index}[$i] = \$data; next }

        my $error = "$md5: missing data!\n";
        next unless my $temp = $buffer->{temp}
            || File::Temp->new( DIR => $repo, SUFFIX => ".$md5", UNLINK => 0 );

        for my $data ( @{ $buffer->{$index} } )
        {
            unless ( $data ) { $data = \NULL; warn $error }
            print $temp $$data;
        }

        delete $buffer->{$index};
        next if $i == MAXBUF;
        seek $temp, 0, 0;

        if ( $md5 eq Digest::MD5->new()->addfile( $temp )->hexdigest() )
        { system "mv $temp $file" } else { unlink $temp }
       
        close $temp;
        delete $buffer{$md5};
    }
}

1;
