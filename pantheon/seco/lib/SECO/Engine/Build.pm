package SECO::Engine::Build;

use base qw( SECO::Engine );

use strict;
use warnings;

use Carp;
use File::Temp;

our $LIST = 'build.list';
our %CONF = %SECO::Engine::CONF;
our %DATA =
(
    build => { dir => 'TransData', list => $LIST },
    pack => { dir => 'pack_conf', list => 'docIDConv' },
);

our %LOG =
map { $_ => "$_.log" } qw( importDOC buildIndex mergeIndex indexPack );

=head3 start( %run )

unzip data and build index in $run{mode} ( full, incr, pack ),
with $run{cpu} of CPUs, sleep $run{sleep} when merge incr.
keep source data if $run{nopurge}.

=cut
sub start
{
    my ( $self, %run ) = splice @_;
    my $data =  $DATA{build};
    my $list = $self->path( data => @$data{ qw( dir list ) } );
    my $cpu = ( $run{cpu} ||= $self->{cpu} ) > $self->{cpu}
        ? $self->{cpu} : $run{cpu};

    system "rm -f $list.*";
    $self->purge( 0 ) if my $full = lc( $run{mode} ||= 'full' ) eq 'full';
    $list = $self->unzip( $list, $cpu );

    my %log = map { $_ => $self->path( log => $LOG{$_} ) } keys %LOG;
    my ( $zlog, $conf ) = map { $self->path( run => $CONF{$_} ) }
        qw( stderr main );

    my $argv = "-c $conf -p $cpu";
    my %argv = ( argv => "$argv -i $list" .
        ( $run{nozlog} ? '' : " -l $zlog" ) . ( $full ? ' -s' : '' ) );

    $self->prun( importDOC => %argv, log => $log{importDOC} );
    eval
    {
        %argv = ( argv => $argv . ( $full ? ' -f' : ' -i' ) );
        $self->prun( buildIndex => %argv, log => $log{buildIndex} );
    };

    my $code = $@ && $@ =~ /with code (\d+)/ ? $1 : 0;
    die "$@" if $code == 1;

    my $sleep = $run{sleep} || 0;
    %argv = ( argv => "$argv -m " . ( $full ? 2 : "0 -s $sleep" ) );

    $self->prun( mergeIndex => %argv, log => $log{mergeIndex} )
        if $full || ! $code;

    $self->purge( $run{nopurge} );
    system "mv $list $list.done";

    if ( $run{mode} eq 'pack' )
    {
        $data = $DATA{pack};
        system "mkdir -p " . $self->path( data => $data->{dir} );
        $list = $self->path( data => @$data{ qw( dir list ) } );

        eval
        {
            %argv = ( argv => "-c $conf -o $list -s", log => $log{indexPack} );
            $self->prun( packGen => %argv );
    
            %argv = ( argv => "$argv -i $list -s", log => $log{indexPack} );
            $self->prun( packDOC => %argv )->prun( packIndex => %argv );
        };

        return 0 if $@;
        %argv = ( argv => "-c $conf -s .pack", log => $log{indexPack} );
        $self->prun( moveDOC => %argv );
    }

    $self->prun( qsrchTool => ( argv => "-c $conf", input => 'abc' ) );
    return 1;
}

sub purge
{
    my ( $self, $keep ) = splice @_;
    my $zero = defined $keep && ! $keep;
    my $data =  $DATA{build};
    my $list = $self->path( data => @$data{ qw( dir list ) } );

    for my $name ( qw( qbuild qindex qstorage ) )
    {
        my $dir = $self->path( data => $name );
        map { system "mkdir -p $dir/$_" }
            0 .. $self->env( uc $name => 'partition' ) - 1;

        system "find -L $dir -name '$name*' -type f -exec rm -f {} \\;"
            if $zero;

        next if $name ne 'qbuild';
        system "mkdir -p $dir/temp";
        system "rm -rf $dir/*/*" unless $keep;
    }
    return $self;
}

=head3 unzip( $max )

unzip '.gz' files, $max at a time

=cut
sub unzip
{
    local $/ = "\n";
    local $| = 1;

    my ( $self, $list, $max ) = splice @_;
    my $temp = File::Temp->new( UNLINK => 0, SUFFIX => ".$LIST" );

    confess "open $list: $!" unless tie my @list, 'Tie::File', $list;
    $list .= '.unzip';

    my ( $count, $curr, $i ) = ( $#list + 1, 0, 0 );

    for ( @list )
    {
        my $file = $_;
        printf STDERR "file %d of $count: $file\n", ++ $i;

        if ( -f $file && $file =~ s/\.gz$// )
        {
            if ( $curr ++ >= $max ) { wait; $curr -- }
            my $pid = fork(); confess "fork: $!" unless defined $pid;
            exec "gzip -df $file.gz &> /dev/null" unless $pid;
        }
        print $temp $file . "\n";
    }

    wait while $curr -- > 0;
    system "mv $temp $list";
    return $list;
}

1;
