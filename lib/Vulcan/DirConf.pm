package Vulcan::DirConf;

=head1 NAME

Vulcan::DirConf - Interface module: directory configuration with a YAML file.

=head1 SYNOPSIS

 use base Vulcan::DirConf;

 sub define { qw( log code ) };

 my $conf = Vulcan::DirConf->new( '/conf/file' );
 my $conf->make() if ! $conf->check;

 my $conf = $conf->path(); ## HASH ref
 my $logdir = $conf->path( 'log' );
 my $logfile = $conf->path( log => 'foobar.log' );

=cut
use strict;
use warnings;
use Carp;
use YAML::XS;
use File::Spec;

sub new
{
    my ( $class, $conf, ) = splice @_;
    my ( %conf, %path ) = ( abscent => {}, path => {} );

    confess "undefined config" unless $conf;
    $conf = readlink $conf if -l $conf;

    my $error = "invalid config $conf";
    confess "$error: not a regular file" unless -f $conf;

    eval { $conf = YAML::XS::LoadFile( $conf ) };

    confess "$error: $@" if $@;
    confess "$error: not HASH" if ref $conf ne 'HASH';

    for ( my $loop = keys %$conf; $loop; )
    {
        for ( $loop = 0; my ( $name, $path ) = each %$conf; )
        {
            $loop = $path{$name} = delete $conf->{$name} if $path !~ /\$/;
        }

        while ( my ( $name, $path ) = each %path )
        {
            map { $conf->{$_} =~ s/\$$name\b/$path/g } keys %$conf;
        }
    }

    confess "$error: unresolved variable" if %$conf;
    my $self = bless \%conf, ref $class || $class;

    map { confess "$error: $_ not defined"
        unless $conf{path}{$_} = $path{$_} } $self->define();
    return $self;
}

=head1 METHODS

=head3 check()

Inspect directories. Returns true if all directories exist, false otherwise.

=cut
sub check
{
    my $self = shift;
    my %dir = reverse %{ $self->{path} };

    map { delete $dir{$_} if -d $_ || -l $_ } keys %dir;
    $self->{abscent} = { reverse %dir };
    return ! keys %dir;
}

=head3 make()

Set up directories. Returns invoking object.

=cut
sub make
{
    my $self = shift;

    map { confess "cannot mkdir $_" if system( "rm -f $_ && mkdir -p $_" ) }
        values %{ $self->{abscent} } unless $self->check();

    $self->{abscent} = {};
    return $self;
}

=head3 path( name => @name )

Join a known path I<name> with @name. See File::Spec->join().

=cut
sub path
{
    my ( $self, $name ) = splice @_, 0, 2;
    my $path = $self->{path};
    return $path unless defined $name;
    return $path unless ( $path = $path->{$name} ) && @_;
    File::Spec->join( $path, @_ );
}

1;
