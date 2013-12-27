package SECO::Engine;

=head1 NAME

SECO::Engine - Search Engine Control Interface

=cut
use strict;
use warnings;

use Carp;
use POSIX;
use Tie::File;
use File::Spec;
use File::Temp;
use Sys::Hostname;
use Time::HiRes qw( sleep );

use SECO::Conf::Auto;

our %PROC = ( retry => 1, sleep => 0.1 );

our %PATH =
(
    var => '/var',
    seco => '/home/s/ops/pantheon/seco/conf',
);

our %CONF =
(
    main => 'config.ini',
    qnet => 'qnet.ini',
    qfedd => 'zlog_qfedd.conf',
    qsrchd => 'zlog_qsrchd.conf',
    qsumd => 'zlog_qsumd.conf',
    stderr => 'zlog_stderr.conf',
    stdout => 'zlog_stdout.conf',
);

sub new
{
    local $/ = "\n";

    my ( $class, %path ) = splice @_;
    my $cpu = `grep -c ^processor /proc/cpuinfo`; chop $cpu;
    my $self = bless
    {
        path => \%path, cpu => $cpu, host => Sys::Hostname::hostname()
    },  ref $class || $class;

    ( $self->{user}, $path{home} ) = ( getpwuid $< )[0,7];

    map { $path{$_} ||= $PATH{$_} } keys %PATH;
    map { $path{$_} ||= $self->path( qw( var ytt ), $_ ) } qw( bin config );
    map { $path{$_} ||= $self->path( qw( home ytt ), $_ ) } qw( run log data );

    $self->setini();
}

=head1 METHODS

=head3 ini

get ini

=cut

sub ini
{
    local $/ = "\n";

    my ( $self, $ini ) = splice @_;
    my $sect = my $null = '';
    my %env = ( $null => {} );
    my $conf = $self->path( run => $CONF{$ini} );

    confess "$conf: $!" unless tie my @conf, 'Tie::File', $conf;

    for ( @conf )
    {
        my $line = $_;
        $line =~ s/#.*$//; $line =~ s/^\s+//; $line =~ s/\s+$//;
        next unless length $line;

        if ( $line =~ /^\[\s*(.+?)\s*\]$/ ) { $sect = $1; next }
        if ( $line =~ /^([^=\s]+)\s*=\s*([^=]+)$/ ) { $env{$sect}{$1} = $2 }
        else { push @{ $env{$sect} }, $line }
    }

    return wantarray ? %env : \%env;
}

=head3 setini

load main config.ini

=cut
sub setini
{
    my $self = shift;
    $self->{env} = $self->ini( 'main' );
    return $self;
}

=head3 env

get env

=cut
sub env
{
    my ( $self, $sect, $key ) = splice @_;
    my $env = $self->{env};

    return $env unless defined $sect;
    $env = $env->{$sect} || {};

    return $env unless defined $key;
    return $env->{$key};
}

=head3 setenv

generate ini configs

=cut
sub setenv
{
    local $/ = "\n";

    my $self = shift;
    my ( $user, $host ) = @$self{ qw( user host ) };
    my $i = $user =~ /(\d+)$/ ? $1 : 1;

    my $conf = SECO::Conf::Auto->new( $self->path( 'seco' ) );
    my $info = $conf->search( $host );

    confess "no seco config!" unless
    my ( $tier, $dc, $replica ) = @{ $info->{$host} };

    my $seco = $conf->{$tier}{$dc};
    $info = $seco->dump( hash => $replica );

    my %macro =
    (
        IDC => $dc, TIER => $tier, REPLICA => $replica, HOSTNAME => $host, 
        BINDIP => ( $self->{ipv4} = $info->{$host}[--$i] ),
        RUN_USER => $user, WORKDIR => $self->path( home => 'ytt' ),
    );

    for my $key ( sort keys %CONF )
    {
        my $name = $CONF{$key};
        my $src = $self->path( config => $name );
        my $dst = $self->path( run => $name );
        my $tmp = File::Temp->new( UNLINK => 0, SUFFIX => ".$key" );

        system "cp $src $tmp";
        confess "open $tmp: $!" unless tie my @file, 'Tie::File', $tmp;

        for ( @file )
        {
            while ( my ( $key, $val ) = each %macro ) { $_ =~ s/<$key>/$val/g }
        }

        if ( $key eq 'qnet' )
        {
            my ( $main, $i ) = ( qr/^p(.+)/, 0 );
            my @seco = [ $tier, $seco ];
            my $port = $self->env( QNET => 'port' ) || confess "no port";

            if ( $tier =~ $main )
            {
                for my $key ( sort keys %$conf )
                {
                    next if $key eq $tier || $key !~ $main;
                    next unless my $seco = $conf->{$key}{$dc};

                    $seco = [ $key, $seco ];
                    if ( $1 eq 'm' ) { unshift @seco, $seco }
                    else { push @seco, $seco }
                }
            }

            for ( @seco )
            {
                my ( $tier, $seco ) = @$_;
                my $comm = $self->env( QNET => "COMM_$tier" ) || '';

                map { push @file, join ':', ++ $i, $_->[0], $port, $_->[1],
                    $comm, $user, $tier, $replica }
                $seco->dump( seco => $replica );
            }
        }

        untie @file;
        system "mv $tmp $dst";
        $self->setini() if $key eq 'main';
    }
    return $self;
}

=head3 path( $name, @name )

join a known path $name with @name.

=cut
sub path
{
    my ( $self, $name ) = splice @_, 0, 2;
    my $path = $self->{path};
    return $path unless defined $name;
    return $path unless ( $path = $path->{$name} ) && @_;
    File::Spec->join( $path, @_ );
}

=head3 prun( $name, %param )

run process with $param{argv}, log output to $param{log}.

if $param{ini} is defined, 'concurrency' is loaded from ini definition, if any,
and a corresponding number of processes will be started.

=cut
sub prun
{
    my ( $self, $name, %param ) = splice @_;
    my ( $argv, $log, $ini, $bg ) = @param{ qw( argv log ini bg ) };
    my $cmd = $self->path( bin => $name );

    confess "$cmd: no such executable" unless -x $cmd;

    $cmd = "echo $param{input} | $cmd" if defined $param{input};
    $cmd = "export WORKDIR=~/ytt;" . $cmd;
    $cmd .= " $argv" if $argv;
    $cmd .= " >> $log 2>&1" if $log;

    my $env = $self->env( $ini );
    my $max = $env->{concurrency} || 1;
    my $err = "$name failed: $cmd";
    my ( $retry, $sleep ) = map { $param{$_} || $PROC{$_} } qw( retry sleep );

    for ( my $i = 0; $self->pgrep( $name ) < $max; sleep $sleep )
    {
        if ( $bg )
        {
            confess "$err\n" if $i ++ > $max + $retry;
            my $pid = fork();
            confess "fork: $!" unless defined $pid;
            confess "exec: $!" if $pid == 0 && exec $cmd;
        }
        elsif ( my $code = system $cmd )
        {
            system POSIX::strftime( "echo %m-%d %H:%M:%S $err", localtime );
            die "$name failed with code $code\n";
        }

        last unless defined $bg;
    }

    return $self;
}

=head3 pkill( $name )

kill processes by $name

=cut
sub pkill
{
    my ( $self, $name, %param ) = splice @_;
    my ( $retry, $sleep ) = map { $param{$_} || $PROC{$_} } qw( retry sleep );

    for ( 0 .. $retry )
    {
        return 1 unless my @pid = $self->pgrep( $name );
        return 1 if @pid == kill 9, @pid;
        sleep $sleep;
    }
    return 0;
}

=head3 pgrep( $name )

list of processes by $name

=cut
sub pgrep
{
    local $/ = "\n";

    my ( $self, $name ) = splice @_;
    my $user = $self->{user};
    my @pid = `pgrep -u $user $name`; chomp @pid;
    return wantarray ? @pid : 0 + @pid;
}

1;
