package CloudOps::SECtrl;

=head1 NAME

CloudOps::SECtrl - CloudOps Search Engine Control

=head1 SYNOPSIS

 use CloudOps::SECtrl;

 CloudOps::SECtrl->online();
 CloudOps::SECtrl->offline();

 CloudOps::SECtrl->start( user => [ qw( search3 search1 ) ] );
 CloudOps::SECtrl->stop( user => [ qw( search3 search1 ) ] );

 CloudOps::SECtrl->build();
 CloudOps::SECtrl->pack();
 CloudOps::SECtrl->qnet( argv => 'info' );

 CloudOps::SECtrl->vips();
 CloudOps::SECtrl->hostlist();

 warn "error\n" unless CloudOps::SECtrl->check();

=cut
use strict;
use warnings;

use Carp;
use File::Temp;
use Sys::Hostname;

use CloudOps::SEConfig;

our ( $ROOT, $USER ) = qw( /var/ytt search );
our ( $CONF, $TOOL ) = map { "$ROOT/$_" } qw( config bin );

our %CONF =
(
    seconfig => "$CONF/seconfig",
    hostlist => "$CONF/hostlist",
);

our %FORK =
(
    build => "$TOOL/daybuild.sh",
    pack => "$TOOL/AutoPack.sh",
);

our %AUTO =
(
    start => "$TOOL/startSrch.sh",
    stop => "$TOOL/stopSrch.sh",
    online => "$TOOL/online.sh",
    offline => "$TOOL/offline.sh",
    qnet => "$TOOL/qnet_ctrl.sh",
    check => "$TOOL/fecheck.sh",
    %FORK,
);

our %TOOL =
(
    vips => "$TOOL/vips.sh",
    %AUTO,
);

sub new
{
    my $class = shift;
    my $host = Sys::Hostname::hostname;
    my $conf = CloudOps::SEConfig->load( shift || $CONF{seconfig} );
    my $vips = $conf->dump( 'vips' );
    my @missing = grep { ! -x $_ } values %TOOL;

    confess join "\n\t", "missing tools:", @missing if @missing;
    confess 'must be superuser' if $<;
    confess 'host not setup'
        unless ( $vips = $vips->{$host} ) && ( my $count = keys %$vips );

    my @user = $count > 1 ? map { $USER . $_ } 1 .. $count : $USER;
    my @seco = $conf->dump( 'seco' );

    bless { user => \@user, seco => \@seco, vips => $vips },
        ref $class || $class;
}

=head METHODS

=head3 vips()

Assign vips, if any.

=cut
sub vips
{
    my ( $self, %param ) = splice @_;
    my $vips = $self->{vips};
    my @vips = keys %$vips;

    return 1 if keys @vips <= 1;
    confess "mask not defined" unless my $mask = $param{mask};
    confess "vlan not defined" unless my $vlan = $param{vlan};
    grep { system "$TOOL{vips} $vips->{$_} $vlan $_ $mask" } @vips ? 0 : 1;
}

=head3 hostlist( $path )

Generate hostlist.

=cut
sub hostlist
{
    my $self = shift;
    my $list = shift || $CONF{hostlist};
    my $i = 1;

    confess $! unless my $temp = File::Temp->new( UNLINK => 0 );

    map { print $temp join( ':', @$_, $i ++ ) ."\n" } @{ $self->{seco} };
    return system( "mv $temp $list" ) ? 0 : 1;
}

=head3 start( %param )

Turn search engine on.

=head3 stop( %param )

Turn search engine off.

=head3 online( %param )

Switch load on.

=head3 offline( %param )

Switch load off.

=head3 qnet( %param )

Print qnet info.

=head3 check( %param )

Check engine.

=head3 build()

Build databases.

=head3 pack()

Pack databases.

=cut
sub AUTOLOAD
{
    my ( $self, %param ) = @_;

    return 0 unless our $AUTOLOAD =~ /::(\w+)$/;
    return 0 unless my $cmd = $FORK{$1};

    my @user = @{ $param{user} || $self->{user} };
    my $argv = $param{argv} || [];
    my @cmd = ( $cmd, ref $argv ? @$argv : $argv );

    return grep { system "sudo -u $_ @cmd" } @user ? 0 : 1 unless $FORK{$1};

    return 1 if my $pid = fork();
    confess "fork $!" unless defined $pid;

    for my $user ( @user )
    {
        next if my $pid = fork();
        exec "sudo -u $user @cmd" if defined $pid;
    }
    exit 0;
}

sub DESTROY {}

1;
