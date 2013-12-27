package SECO::Conf::Auto;

=head1 NAME

SECO::Conf::Auto - Search Engine Configuration

=head1 SYNOPSIS

=cut
use strict;
use warnings;
use Carp;

use SECO::Conf;

sub new
{
    my ( $class, $path ) = splice @_;
    my %self;

    for my $conf ( glob "$path/*\@*" )
    {
        next unless my $seco = eval { SECO::Conf->load( $conf ) };
        my ( $tier, $dc ) = $seco->name();
        $self{$tier}{$dc} = $seco;
    }
    bless \%self, ref $class || $class;
}

sub search
{
    my $self = shift;
    my %node = map { $_ .= $SECO::DOMAIN if $_ !~ /$SECO::DOMAIN/; $_, [] } @_;

    while ( my ( $tier, $conf ) = each %$self )
    {
        while ( my ( $dc, $seco ) = each %$conf )
        {
            for my $i ( 1 .. $seco->replica() )
            {
                my @name = ( $tier, $dc, $i );
                map { $node{$_} = \@name if $node{$_} }
                    $seco->list( host => $i );
            }
        }
    }
    return wantarray ? %node : %node ? \%node : undef;
}

sub name
{
    my $class = shift;
    my $name = shift || '';
    my @name = $name =~ /^([^@]+?)(\d+)@([^@]+)$/;

    @name[1,2] = @name[2,1] if @name;
    return wantarray ? @name : @name ? \@name : undef;
}

sub AUTOLOAD ## list / dump( $want => $seco )
{
    croak "no such method: $1" if our $AUTOLOAD !~ /::(list|dump)$/;

    my ( $self, $want, $name ) = splice @_;
    my @name = $self->name( $name );
    my $tier = @name ? $self->{$name[0]} || {} : {};
    my $seco = $tier->{$name[1]} || SECO::Conf->null();

    $seco->$1( $want => $name[2] );
}

sub DESTROY {}

1;
