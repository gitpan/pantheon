package SECO::Index;

=head1 NAME

SECO::Index - Build Search Index

=cut
use strict;
use warnings;

use Carp;
use Sys::Hostname;
use File::Basename;

use Vulcan::OptConf;

our %HC;

BEGIN
{
    my $hadoop = Vulcan::OptConf->load()->dump( 'hadoop' );
    %HC = %{ $hadoop->{ADDR} };
}

our %TYPE = map { $_ => $_ } qw( data inc full rank );
our %HDFS =
(
    upload => "sh /home/work/software/distcp/put.sh",
    distcp => "sh /home/work/software/distcp/distcp.sh",
    distrm => "sh /home/work/software/distcp/remove.sh",
    getjob => "sh /home/work/software/distcp/getjob.sh",
    map { $_ => "hadoop fs -$_" } qw( ls cat get put rmr mkdir )
);

our %FILE =
(
    list => 'build.list', src => 'TransData',
    map { $_ => $_ } qw( tmp data mark ) 
);

=head1 SYNOPSIS

 use SECO::Index;

 my $index = SECO::Index->new
 (
     version => $version, dc => 'zzbc' hdfs => 'hdfs/path', repo => 'repo/path'
 );

=head1 HDFS

 /home/$USER/cdx/
     $version/$dbid/
         src/$ts.$id.{full,incr,rank}.$count/
         dst/$ts.$id.data.$version.$dbid/

 e.g.

 /home/cloudops/cdx/v0004/0038/src/2013010320220319.00232.incr.03193
 /home/cloudops/cdx/v0004/0038/dst/2013010320220319.00248.data.v0004.0038

=head1 REPO

 /home/$USER/ytt/
     data/ -> $ts.$id.data.$version.$dbid
         Transdata/ -> /home/$USER/ytt

 e.g.

 /home/search/data
 => /home/search/2013010320220319.00248.data.v0004.0038

 /home/search/2013010320220319.00248.data.v0004.0038/Transdata
 => /home/search/data

=head1 FIELD

=head3 $version

CDX version, v0001 .. v9999

=head3 $count

Number of files in director, 00000 .. 99999

=head3 $ts

Timestamp, 2013010320220319

=head3 $id

Increment ID, 00001 .. 99999

=head3 $dbid

Database ID, 0001 .. 0400

=head1 METHODS

=cut
sub new
{
    my ( $class, %self ) = splice @_;   
    map { confess "$_ not defined" unless defined $self{$_} }
        qw( version dc repo hdfs );

    $self{hdfs} .= "/$self{version}";
    $self{link} = "$self{repo}/$FILE{data}";
    $self{host} = Sys::Hostname::hostname();
    bless \%self, ref $class || $class;
}

sub env
{
    my $self = shift;
    do shift if @_;
    return $self;
}

=head3 setup( $data, @path )

set up links and file list

=cut
sub setup
{
    my ( $self, $data, @path ) = splice @_;
    my ( $link, $repo ) = @$self{ qw( link repo ) };

    confess $! if system "mkdir -p $data/qbuild/{0..4}";
    confess $! if system "mkdir -p $data/{qindex,qstorage}/{0..119}";
    confess $! if system "mkdir -p $repo/{run,log}";

    return $self unless @path;

    open my $fh, '>', my $temp = "$repo/.$FILE{list}";
    map { print $fh "$_\n" } map { glob "$_/*" } @path;
    close $fh;

    confess $! if system "mv $temp $repo/$FILE{list}";
    return $self;
}

=head3 id( $name )

get id section of $name

=cut
sub id
{
    my ( $self, $name ) = splice @_;
    my @name = split '\.', File::Basename::basename $name;
    return wantarray ? @name : $name[1];
}

1;
