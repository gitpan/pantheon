package Vulcan::Mrsync;

=head1 NAME

Vulcan::Mrsync - Replicate data via phased rsync

=head1 SYNOPSIS

 use Vulcan::Mrsync;

 my $mrsync = Vulcan::Mrsync->new
 ( 
     src => \@src_hosts,
     dst => \@dst_hosts,
     sp => $src_path,
     dp => $dst_path, ## defaults to sp
 );

 $mrsync->run
 (
     timeout => 300, ## default 0, no timeout
     retry => 2,     ## default 0, no retry
     log => $log_handle,    ## default \*STDERR
     max => $max_in_flight, ## default 2
     opt => $rsync_options, ## default -aqz
 );

=cut
use strict;
use warnings;

use Carp;
use File::Basename;

use base qw( Vulcan::Phasic );

our %RUN = ( retry => 2, opt => '-aqz' );

sub new
{
    my ( $class, %param ) = splice @_;
    my ( $sp, $dp ) = delete @param{ qw( sp dp ) };
    my %src = map { $_ => 1 } @{ $param{src} };

    $sp = $dp unless $sp;
    $dp = $sp unless $dp;

    croak "path not defined" unless $sp;

    if ( $sp =~ /\/$/ ) { $dp .= '/' if $dp !~ /\/$/ }
    elsif ( $dp =~ /\/$/ ) { $dp .= File::Basename::basename( $sp ) }

    my $w8 = sub 
    {
        my @addr = gethostbyname shift;
        return @addr ? unpack N => $addr[-1] : 0;
    };

    my $rsync = sub
    {
        my ( $src, $dst, %param ) = splice @_;
        my $sp = $src{$src} ? $sp : $dp;
        my $ssh = 'ssh -o StrictHostKeyChecking=no';

        my $cmd_user = << "USER";
$ssh $dst nice -n 19 'rsync -e "$ssh" $param{opt} $src:$sp $dp'
USER

        my $cmd_root = << "ROOT";
$ssh $dst nice -n 19 ionice -c3 'rsync -e "$ssh" $param{opt} $src:$sp $dp'
ROOT
        my $rsync = my $cmd = $< ? $cmd_user : $cmd_root;

        chop $rsync;
        #&{ $param{log} }( $cmd );
        return system( $rsync ) ? die "ERR: $cmd" : 'OK';
    };

    bless $class->SUPER::new( %param, weight => $w8, code => $rsync ),
        ref $class || $class;
}

sub run
{
    my ( $self, %run ) = splice @_;
    $Vulcan::Phasic::MAX = delete $run{max} if $run{max};
    $self->SUPER::run( %RUN, %run );
    return $self;
}

1;
