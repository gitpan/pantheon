package Vulcan::OptConf;
=head1 NAME

Vulcan::OptConf - Get command line options.

=cut
use strict;
use warnings;
use Carp;
use YAML::XS;
use Pod::Usage;
use Getopt::Long;
use FindBin qw( $RealScript $RealBin );

$| ++;

our ( $ARGC, $THIS, $CONF, @CONF ) = ( 0, $RealScript, '.config' );

=head1 SYNOPSIS

 use Vulcan::OptConf;

 $Vulcan::OptConf::ARGC = -1;
 @Vulcan::OptConf::CONF = qw( pass_through );

 my $option = Vulcan::OptConf->load( '/conf/file' );

 my %foo = $option->dump( 'foo' );

 my %opt = $option->set( bar => 'baz' )->get( 'timeout=i', 'verbose' )->dump;

=head1 METHODS

=head3 load( $conf )

Load options from a YAML file $conf, which when unspecified, defaults to
$RealBin/.config, or $RealBin/../.config, if either exists. Returns object.

=cut
sub load
{
    my $class = shift;
    my $self = {};
    my @conf =  map { File::Spec->join( $RealBin, $_, $CONF ) } qw( . .. );
    my ( $conf ) = @_ ? @_ : grep { -e $_ } @conf;

    if ( $conf )
    {
        my $error = "invalid config $conf";
        $conf = readlink $conf if -l $conf;
        confess "$error: not a regular file" unless -f $conf;

        $self = eval { YAML::XS::LoadFile( $conf ) };
        confess "$error: $@" if $@;
        confess "$error: not HASH" if ref $self ne 'HASH';
    }

    $self->{$THIS} ||= {};
    bless $self, ref $class || $class;
}

=head3 dump( $name )

Dump options by $name, or that of $0 if $name is unspecified.
Returns HASH in scalar context or flattened HASH in list context.

=cut
sub dump
{
    my $self = shift;
    my %opt = %{ $self->{ @_ ? shift : $THIS } || {} };
    return wantarray ? %opt : \%opt;
}

=head3 set( %opt )

Set options specified by %opt for $0. Returns object.

=cut
sub set
{
    my ( $self, %opt ) = splice @_;
    map { $self->{$THIS}{$_} = $opt{$_} } keys %opt;
    return $self;
}

=head3 get( @options )

Invoke Getopt::Long to get @options, if any specified. Returns object.

Getopt::Long is configured through @CONF.

The leftover @ARGV size is asserted through $ARGC. @ARGV cannot be empty
if $ARGC is negative, otherwise size of @ARGV needs to equal $ARGC.

=cut
sub get
{
    my $self = shift;
    Getopt::Long::Configure( @CONF ) if @CONF;
    Pod::Usage::pod2usage( -input => $0, -output => \*STDERR, -verbose => 2 )
        if ! Getopt::Long::GetOptions( $self->{$THIS}, @_ )
        || $ARGC < 0 && ! @ARGV || $ARGC > 0 && @ARGV != $ARGC;
    return $self;
}

1;
