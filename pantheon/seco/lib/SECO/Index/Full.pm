package SECO::Index::Full;

use base qw( SECO::Index );

=head1 NAME

SECO::Index::Full - Build Full Search Index

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Basename;

use Vulcan::ProcLock;
use SECO::Index::Log;
use SECO::Engine::Build;

our %HC = %SECO::Index::HC;
our %HDFS = %SECO::Index::HDFS;
our %FILE = %SECO::Index::FILE;
our %TYPE = %SECO::Index::TYPE;

=head1 SYNOPSIS

 use SECO::Index::Full;

 my $index = SECO::Index::Full->new
 (
     version => $version, hdfs => 'hdfs/cdx/path', repo => 'data/repo/path',
 );

 $index->get( count => 2 );
 $index->run();
 $index->put();

=head1 HDFS

 /home/cloudops/cdx/
   $version/$dbid/
     src/$ts.$id.{full,incr,rank}.$count/
     dst/$ts.$id.data.$version.$dbid/

=head1 REPO

 /home/$USER/ytt/
   data/ -> $ts.$id.data.$version.$dbid
     Transdata/ -> /home/$USER/ytt

=cut

sub get
{
    local $/ = "\n";
    local $| = 1;

    my ( $self, %param ) = splice @_;
    my ( $repo, $dc, $hdfs, $host ) = @$self{ qw( repo dc hdfs host ) };

    ## remove remained dirty tmp dirs
    map { system "rm -rf $_" } glob "$repo/*.$TYPE{full}.*.tmp";

    while ( ( () = glob "$repo/*.$TYPE{full}.*" ) < ( $param{count} ||= 1 ) )
    {
        ## find oldest newest without mark
        my ( $time, $name ) = time;

        my %sort = map { join('.', ( split /\//, $_ )[-1,-3] ) => $_ }
            grep { /full/ }  $self->hdls( "$hdfs/*/src" );

        for ( reverse sort keys %sort )
        {
            my $mark = "$sort{$_}/.$FILE{mark}";
            my @name = $self->id( $_ );

            next unless system( "$HDFS{ls} $mark" )
                || ( grep { $_ =~ $host } `$HDFS{cat} $mark` )
                && system( "ls $repo/$_" )
                && system( "ls $repo/$name[0].*.$TYPE{data}.*.$name[-1]" )
                && system( "$HDFS{ls} $hdfs/$name[-1]/dst/$name[0].*" );
            $name = $_; last;
        }
        return 0 unless $name;

        ## create mark
        my $path = $sort{$name};
        my $mark = "$repo/.$FILE{mark}";
        YAML::XS::DumpFile $mark, +{ $host, $time };

        next unless ! system( "$HDFS{put} $mark $path/.$FILE{mark}" )
            || ( grep { $_ =~ $host } `$HDFS{cat} $path/.$FILE{mark}` );
        
        $self->log( mesg => "start to get $path" );
        ## get it
        my $temp = "$repo/$name.$FILE{tmp}";
        $self->alarm( $!, 'get' ) if system "$HDFS{get} -crc $path $temp";
        $self->alarm( $!, 'get' ) if system "mv $temp $repo/$name";
        $self->log( mesg => "success to get $path" );
    }
    return $self;
}

sub run
{
    my ( $self, %param ) = splice @_;
    my ( $repo, $link, $version ) = @$self{ qw( repo link version ) };

    return $self if -f "$repo/run/indexrun.error";
    map { system "rm -rf $_" } glob "$repo/*.$TYPE{data}.*.tmp";

    for my $path ( glob "$repo/*.$TYPE{full}.*" )
    {
        return $self if ( () = glob "$repo/*.$TYPE{data}.*" ) > 1;
        my @name = File::Basename::fileparse( $path, ".$FILE{tmp}" );
        next if pop @name;

        ## setup data dir and links
        @name = $self->id( $name[0] );
        splice @name, 2, 2, $TYPE{data}, $version;
        my $data = $repo. '/' . join '.', @name;
        my $temp = "$data.$FILE{tmp}";

        $self->setup( $temp, $path );

        confess $! if system "rm -rf $link; ln -s $temp $link" ||
            system "rm -rf $link/$FILE{src}; ln -sf $repo $link/$FILE{src}";

        ## build and verify
        $self->log( mesg => "start to build $temp" );

        my $ok = eval { SECO::Engine::Build->new()->start
            ( mode => 'full', nopurge => 1, nozlog => $param{nozlog} ) };

        $self->alarm( $@, 'run' ) if $@;
        $self->alarm( 'build failed', 'run' ) unless $ok;
        $self->log( mesg => "success to build $temp" );

        system "rm -rf $link/qbuild/*/*";
        unlink "$link/$FILE{src}", $link;
        $self->alarm( $!, 'run' ) if system "rm -rf $data; mv $temp $data";
        system "rm -rf $path";
    }
    return $self;
}

sub put
{
    local $/ = "\n";
    local $| = 1;

    my ( $self, %param ) = @_;
    my ( $repo, $hdfs, $version, $dc ) = @$self{ qw( repo hdfs version dc ) };

    for my $path ( glob "$repo/*.$TYPE{data}.*" )
    {
        my @name = File::Basename::fileparse( $path, ".$FILE{tmp}" );
        next if pop @name;

        ## put data 
        @name = split '\.', my $name = shift @name;
        my $dbid = pop @name;

        unless ( system "$HDFS{ls} $hdfs/$dbid/dst/$name" )
        {
            system "rm -rf $path"; next;
        }

        next if pop @name ne $version;

        while ( my ( $name, $addr ) = each %HC )
        {
            my $dst = "$addr/$hdfs/$dbid/dst";
            system "$HDFS{ls} $dst || $HDFS{mkdir} $dst";
        }

        $self->log( mesg => "start to put $path to hadoop" );
        $self->alarm( $!, 'put' )
            if system "$HDFS{upload} $path $HC{$dc}/$hdfs/$dbid/dst/$name";
        $self->log( mesg => "success to put $path to hadoop" );

        ## prepare for sync and clean up local hadoop old files
        system "mkdir -p $repo/.syncdir";
        map { system "touch $repo/.syncdir/$name.$_" if $_ !~ /$dc/ } keys %HC;

        $self->do_cleanup( $dc, $hdfs, $dbid, $name[0] ) if $param{purge};
        system "rm -rf $path";
    }
    return $self;
}

sub sync_and_cleanup
{
    my ( $self, %param ) = @_;
    my ( $repo, $dc, $hdfs ) = @$self{ qw( repo dc hdfs ) };

    for my $sync ( glob "$repo/.syncdir/*" )
    {
        next if my $pid = fork();

        my $lock = Vulcan::ProcLock->new( $sync );
        exit 0 unless $lock->lock();

        my $name = File::Basename::basename( $sync );
        my ( $path, $dst ) = $name =~ /^(.*)\.(\w+)$/;
        my @name = split '\.', $path;
        my $dbid = pop @name;
        $path = "$hdfs/$dbid/dst/$path";

        $self->log( mesg => "start to sync $path from $dc to $dst" );
        if ( ! $self->do_sync( $dc, $dst, $path ) )
        {
            $self->log( mesg => "failed to sync $path from $dc to $dst" );
            exit 1;
        }
        $self->log( mesg => "success to sync $path from $dc to $dst" );
        $self->do_cleanup( $dst, $hdfs, $dbid, $name[0] ) if $param{purge};

        system "rm -f $sync";
        exit 0;
    }

    return $self;
}

sub do_cleanup
{
    my ( $self, $dst, $hdfs, $dbid, $ts ) = splice @_;
    my %sort = map { File::Basename::basename( $_ ) => $_ }
        $self->hdls( "$HC{$dst}/$hdfs/$dbid/*" );

    map { system "$HDFS{rmr} $HC{$dst}/$sort{$_}" if $_ lt $ts } sort keys %sort
}

sub hdls
{
    local $/ = "\n";
    my ( $self, $path ) = splice @_;
    map { ( split /\s+/, $_ )[-1] } `$HDFS{ls} $path`;
}

sub do_sync
{
    my ( $self, $src, $dst, $path ) = splice @_;

    my $repo = $self->{repo};
    chdir $repo;

    my @job = `$HDFS{distcp} $HC{$src}/$path $HC{$dst}/$path`;

    if ( $job[0] !~ qr/^(job_[\d_]+)/ )
    {
        warn join "\n", 'failed', @job, '';
        return 0;
    }

    my $job = $1;
    warn "[$job] sync from $HC{$src}/$path to $HC{$dst}/$path\n";

    while ( sleep 3 )
    {
        my ( $stat ) = `$HDFS{getjob} $job`;
        next if ! $stat || $stat =~ /^running\b/;

        warn "[$job] $stat\n";
        return $stat =~ /^success\b/ ? 1 : 0;
    }
}

sub alarm
{
    my ( $self, $mesg, $type ) = splice @_;
    my $repo = $self->{repo};

    system "touch $repo/run/index$type.error";
    $self->log( type => 'FAILED', mesg => "$type $mesg" );
    confess $mesg;
}

sub log
{
    my ( $self, %param ) = splice @_;
    my ( $mesg, $type ) = @param{ qw( mesg type ) };

    warn "$mesg\n";
    $type = $type ? "[$type]" : '[INFO]';
    SECO::Index::Log::logto( code => 'log',
        argv => [ "$type $self->{host} $mesg" ] );
}

1;
