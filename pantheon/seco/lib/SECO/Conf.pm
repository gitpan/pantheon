package SECO::Conf;

use base qw( SECO );

=head1 NAME

SECO::Conf - Search Engine Configuration

=head1 SYNOPSIS

 use SECO::Conf;

 my $conf = SECO::Conf->load( '/conf/file' );

 my @host = $conf->list( host => 2 ); ## host list of 2nd replica
 my @vips = $conf->list( vips => 1 ); ## vips list of 1st replica

 my %vips = $conf->dump( vips => 3 );
 my @seco = $conf->dump( seco => 1 );
 my %conf = $conf->dump( hash => 2 );

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use Sys::Hostname;
use File::Basename;

sub new
{
    my $self = shift;
    $self->load( @_ );
}

sub load
{
    my ( $class, $conf ) = splice @_;
    my ( @conf, @replica ) = eval { YAML::XS::LoadFile $conf };
    my @name = File::Basename::basename( $conf ) =~ /^([^@]+)@([^@]+)$/;
    my $error = "Invalid config: $conf";

    confess "$error: $@" if $@ && ! @name;

    my @self = \@name;
    my $zone = $name[1] . $SECO::DOMAIN;

    for my $i ( 1 .. @conf )
    {
        my ( $conf, %vips, %eth, @conf ) = shift @conf;
        my $error = "$error part $i";
        confess "$error: not HASH" if ref $conf ne 'HASH';

        my @id = sort { $a <=> $b } keys %$conf;
        confess "$error: invalid first ID" if $id[0] != 1;
        confess "$error: ID not contiguous" if @id != $id[-1];

        for my $id ( @id )
        {
            my $error = "$error: $id";
            my $conf = $conf->{$id};

            confess "$error: not ARRAY" unless $conf && ref $conf eq 'ARRAY';
            confess "$error: invalid definition" if @$conf <= 2;

            my ( $host, $eth ) = splice @$conf, 0, 2;

            $host .= ".$zone";
            confess "$error: duplicate host $host" if $vips{$host};
            $vips{$host} = {};

            for my $i ( 0 .. @$conf - 1 )
            {
                my $ip = $conf->[$i];
                confess "$error: duplicate IP $ip" if $eth{$ip};
                confess "$error: invalid IP $ip" unless ipv4( $ip );
                $vips{$host}{$ip} = "$eth:$i" if ( $eth{$ip} = @$conf ) > 1;
            }
            push @conf, [ $host => [ @$conf ] ];
        }

        map { delete $vips{$_} unless %{ $vips{$_} } } keys %vips;
        push @self, { conf => \@conf, vips => \%vips };
    }

    bless \@self, ref $class || $class;
}

sub null
{
    my $class = shift;
    bless [ [] ], ref $class || $class;
}

sub name
{
    my $self = shift;
    my $name = $self->[0];
    return wantarray ? @$name : $name->[0];
}

sub replica
{
    my $self = shift;
    return @$self - 1;
}

sub index
{
    my ( $self, $index ) = splice @_;
    my @index = 1 .. @$self - 1;

    return $index >= $index[0] && $index <= $index[-1] ? $index : undef
        if defined $index && $index =~ /^\d+$/;

    $index ||= Sys::Hostname::hostname;

    for my $i ( @index )
    {
        map { return $i if $_->{$index} } @{ $self->[$i]{conf} };
    }
    return undef;
}

sub list
{
    my ( $self, $want, $index ) = splice @_;
    my @list;

    if ( $index = $self->index( $index ) )
    {
        my $conf = $self->[$index]{conf} || [];
        @list = $want =~ /host/i
            ? map { $_->[0] } @$conf : map { $_->[1] } @$conf;
    }
    return wantarray ? @list : \@list;
}

sub dump
{
    my ( $self, $want, $index ) = splice @_;
    my ( @conf, %conf );
    my $conf = $self->[$index] if $index = $self->index( $index );

    if ( $want =~ /seco/i )
    {
        if ( $conf ) 
        {
            for my $conf ( @{ $conf->{conf} } )
            {
                my ( $host, $ip ) = @$conf;
                push @conf, map { [ $_ => $host ] } @$ip;
            }
        }
        return wantarray ? @conf : \@conf;
    }

    unless ( $conf )
    {
    }
    elsif ( $want =~ /vip/i )
    {
        %conf = %{ YAML::XS::Load( YAML::XS::Dump $conf->{vips} ) };
    }
    else
    {
        for my $conf ( @{ $conf->{conf} } )
        {
            my ( $host, $ip ) = @$conf;
            $conf{$host} = [ @$ip ];
        }
    }
    return wantarray ? %conf : \%conf;
}

sub ipv4
{
    my $ip = shift;
    my @ip = $ip =~ qr/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/o;
    return @ip && ! grep { $_ =~ /^0/ || $_ > 255 } @ip;
}

1;
