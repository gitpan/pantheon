package SECO::Engine::Search;

use base qw( SECO::Engine );

use strict;
use warnings;

our $STAT = 'status.html';
our %CONF = %SECO::Engine::CONF;
our %LOG =
(
    qsumd => 'qsum.log', qsrchd => 'qsrch.log',
    qcached => 'qcache.log', qrwt => 'qrwt.log',
);

=head3 start()

start engine

=cut
sub start
{
    my ( $self, %run ) = splice @_; $self->setenv();

    my %log = map { $_ => $self->path( log => $LOG{$_} ) } keys %LOG;
    my %conf = map { $_ => $self->path( run => $CONF{$_} ) } qw( main qnet );
    my %argv = ( argv => "-c $conf{main}", bg => 1 );

    my $ipv4 = $self->{ipv4};
    my $env = $self->env( 'QFED' );
    my ( $max, $port ) = @$env{ qw( concurrency port ) };
    my %mode = map { $_ => 1 } split ':', ( $run{mode} || '' );

    $self->prun( qnetd => %argv, argv => "-nrtf $conf{qnet}", bg => 0 );

    unless ( $mode{qrw} )
    {
        $self->prun( qsrchd => %argv, log => $log{qsrchd}, ini => 'QSRCH' );
        $self->prun( qsumd => %argv, log => $log{qsumd}, ini => 'QSUM' );
    }

    $self->cache( on => %argv, log => $log{qcached} ) unless $mode{nocache};

    if ( $mode{qrw} )
    {
        $self->prun( qrwtd => %argv, log => $log{qrwtd}, ini => 'QREWRITE' )
    }
    else
    {
        $self->prun( qfedd => %argv, argv => "$ipv4 -n $max $port" )
    }
    return 1;
}

=head3 stop()

stop engine

=cut
sub stop
{
    my $self = shift;
    return ! grep { ! $self->pkill( $_ ) }
        qw( qrwtd qfedd qcached qsumd qsrchd qnetd );
}

=head3 cache( $stat )

start or stop cache

=cut
sub cache
{
    my ( $self, $stat, %argv ) = splice @_;

    return $self->pkill( 'qcached' ) unless $stat && $stat =~ /^start|on|up$/i;

    unless ( %argv )
    {
        my $log = $self->path( log => $LOG{qcached} );
        my $conf = $self->path( run => $CONF{main} );
        %argv = ( argv => "-c $conf", log => $log, bg => 1 );
    }

    return $self->prun( qcached => %argv );
}

=head3 load( $stat )

check or set load $stat

=cut
sub load
{
    my ( $self, $stat ) = splice @_;
    my $path = $self->path( run => $STAT );

    return -f $path unless defined $stat;
    system sprintf "%s $path", $stat =~ /^start|on|up$/i ? 'touch' : 'rm -f';
}

=head3 status

check status

=cut
sub status
{
    my $self = shift;
    my %stat = map { $_ => scalar $self->pgrep( $_ ) }
        qw( qrwtd qfedd qcached qsumd qsrchd qnetd );
    return wantarray ? %stat : \%stat;
}

1;
