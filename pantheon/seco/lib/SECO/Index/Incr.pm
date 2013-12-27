package SECO::Index::Incr;

use base qw( SECO::Index );

=head1 NAME

SECO::Index::Incr - Build Search Index Incremental

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Basename;

use SECO::Engine::Build;
use SECO::Engine::Search;

our %FILE = %SECO::Index::FILE;
our %TYPE = %SECO::Index::TYPE;

=head1 SYNOPSIS

 use SECO::Index::Incr;

 my $index = SECO::Index::Incr->new
 (
     version => $version, hdfs => 'hdfs/cdx/path', repo => 'data/repo/path',
 );

 $index->get();
 $index->run();

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
    my ( $repo, $hdfs ) = @$self{ qw( repo hdfs ) };
    my ( $dbid, $curr ) = $param{dbid} || confess "no dbid";
    my @data = `ls -d $hdfs/$dbid/dst/*.$TYPE{data}.*`; chomp @data;
    my %id = map { File::Basename::basename( $_ ) => scalar $self->id( $_ ) }
        @data;

    for my $path ( glob "$repo/*.$TYPE{data}.*" )
    {
        my @name = File::Basename::fileparse( $path, ".$FILE{tmp}" );
        next if pop @name;
        $curr = $name[0] unless
            $curr && $self->id( $name[0] ) <= $self->id( $curr );
    }

    ## select full, if any
    if ( $curr )
    {
        my ( $mark, $id ) = "$repo/$curr/.$FILE{mark}";
        confess "invalid id" if -f $mark &&
            ( $id = eval { YAML::XS::LoadFile $mark } || '' ) !~ qr/^\d{4}$/;

        $id{$curr} = $id ||= scalar $self->id( $curr );
        map { delete $id{$_} if $id{$_} < $id } keys %id;
    }

    return $self unless my ( $next ) = reverse sort keys %id;

    my $data = "$repo/$next";
    my $path = "$hdfs/$dbid/dst/$next";

    unless ( -d $data )
    {
        my $temp = "$data.$FILE{tmp}";
        confess $! if system "rsync -av $path/ $temp && mv $temp $data";
        return $self;
    }

    my @path = sort `ls -d $hdfs/$dbid/src/*.{inc,rank}.*`; chomp @path;

    ## select incr and rank
    for my $path ( @path )
    {
        my @name = $self->id( my $name = File::Basename::basename( $path ) );
        next if $name[1] <= $id{$next} || ( () = glob "$repo/$name*" );

        my $data = "$repo/$name";
        my $temp = "$data.$FILE{tmp}";

        confess $! if system "rsync -av $path/ $temp && mv $temp $data";
        last;
    }
    return $self;
}

sub run
{
    my ( $self, %param ) = @_; 
    my ( $repo, $link, $version ) = @$self{ qw( repo link version ) };
    my ( $curr, @data ) = readlink $link if -l $link;
    my $mode = $param{mode};

    if ( $mode eq 'full' )
    {
        ## switch to latest full, if any
        for my $path ( glob "$repo/*.$TYPE{data}.*" )
        {
            my @name = File::Basename::fileparse( $path, ".$FILE{tmp}" );
            push @data, $path unless pop @name;
        }

        if ( @data ) { $curr = pop @data; system "rm -rf @data" }

        return $self unless $curr;

        confess $! if system "rm -rf $link; ln -s $curr $link" ||
            system "rm -rf $link/$FILE{src}; ln -sf $repo $link/$FILE{src}"; 

        return $self;
    }

    return $self unless $curr;

    ## select rank
    my $mark = "$curr/.$FILE{mark}";
    my ( $id, %id );

    unless ( -f $mark )
    {
        $id = scalar $self->id( $curr );
        YAML::XS::DumpFile $mark, $id;
    }
    elsif ( ( $id = eval { YAML::XS::LoadFile $mark } || '' ) !~ /^\d{4}$/ )
    {
        confess "invalid id";
    }

    for my $path ( glob "$repo/*.$TYPE{rank}.*" )
    {
        my @name = File::Basename::fileparse( $path, ".$FILE{tmp}" );
        push @data, [ $path ] unless pop @name
            || ( $id{$path} = $self->id( $name[0] ) ) <= $id;
    }
    return $self unless @data;

    # sort incr by rank
    for my $path ( glob "$repo/*.$TYPE{inc}.*" )
    {
        my @name = File::Basename::fileparse( $path, ".$FILE{tmp}" );
        next if pop @name || ( $id{$path} = $self->id( $name[0] ) ) < $id;

        for my $data ( @data )
        {
            next if $id{$path} > $id{ $data->[0] };
            push @$data, $path; last;
        }
    }

    # check
    map { push @$_, shift @$_ } @data;
    map { confess "incontiguous id!" if ++ $id != $id{$_} } map { @$_ } @data;

    my $data = shift @data;
    $self->setup( $curr, @$data );

    confess $! unless SECO::Engine::Build->new()
       ->start( mode => $mode, nozlog => $param{nozlog} );

    YAML::XS::DumpFile $mark, $id{ $data->[-1] };
    map { system "rm -rf $_" } @$data;

    return $self;
}

1;
