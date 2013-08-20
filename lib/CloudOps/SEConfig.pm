package CloudOps::SEConfig;

=head1 NAME

CloudOps::SEConfig - CloudOps Search Engine Config

=head1 SYNOPSIS

 use CloudOps::SEConfig;

 my $conf = CloudOps::SEConfig->load( '/conf/file' );

 my @conf = $conf->dump();
 my @host = $conf->list( host => 0 );
 my @vips = $conf->list( vips => 0 );
 my %vips = $conf->dump( 'vips' );
 my @seco = $conf->dump( 'seco' );
 my %conf = $conf->dump( 'hash' );

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Basename;

our $DOMAIN = '.qihoo.net';

sub load
{
    my ( $class, $conf ) = splice @_;
    my ( $name, $zone ) = split '@', basename( $conf );
    my ( @conf, %vips, %eth ) = eval { YAML::XS::LoadFile $conf };
    my $error = "Invalid config: $conf";

    confess "$error: $@" if $@;
    confess "$error: empty config" unless @conf;

    $zone = $zone ? ".$zone" : '';
    $zone .= $DOMAIN if $zone !~ /(?:net|com|edu|org)$/;

    for ( 0 .. $#conf )
    {
        my $conf = shift @conf;
        confess "$error: not HASH" if ref $conf ne 'HASH';

        my ( @id, @list ) = sort { $a <=> $b } keys %$conf;
        confess "$error: invalid first ID" if $id[0] != 1;
        confess "$error: ID not contiguous" if @id != $id[-1];

        for my $id ( @id )
        {
            my $error = "$error: $id";
            my $conf = $conf->{$id};

            confess "$error: not ARRAY" unless $conf && ref $conf eq 'ARRAY';
            confess "$error: invalid definition" if @$conf <= 1;

            my ( $host, $eth ) = my @net = split ':', shift @$conf;
            confess "$error: invalid host:eth definition" unless @net == 2;
            confess "$error: duplicate host $host" if $vips{$host};
            $vips{$host} = {};

            for my $i ( 0 .. @$conf - 1 )
            {
                my $ip = $conf->[$i];
                confess "$error: duplicate IP $ip" if $eth{$ip};
                confess "$error: invalid IP $ip" unless ipv4( $ip );
                $vips{$host}{$ip} = "$eth:$i" if ( $eth{$ip} = @$conf ) > 1;
            }
            push @list, { $host.$zone => $conf };
        }
        push @conf, \@list;
    }

    map { delete $vips{$_} unless %{ $vips{$_} } } keys %vips;

    bless { name => $name, conf => \@conf, vips => \%vips },
        ref $class || $class;
}

sub name
{
    my $self = shift;
    return $self->{name};
}

sub list
{
    my ( $self, $want, $sect ) = splice @_;
    my @conf = @{ $self->{conf}[ $sect ||= 0 ] };
    my @list = $want =~ /host/i
        ? map { keys %$_ } @conf : map { values %$_ } @conf;

    return wantarray ? @list : \@list;
}

sub dump
{
    my ( $self, $want ) = splice @_;
    my ( %conf, @conf );

    if ( ( $want ||= 'seco' ) =~ /seco/i )
    {
        for my $conf ( @{ $self->{conf} } )
        {
            for my $conf ( @$conf )
            {
                my ( $host, $ip ) = each %$conf;
                push @conf, map { [ $_ => $host ] } @$ip;
            }
        }
        return wantarray ? @conf : \@conf;
    }

    if ( $want =~ /vip/i )
    {
        %conf = %{ YAML::XS::Load( YAML::XS::Dump $self->{vips} ) };
    }
    else
    {
        for my $conf ( @{ $self->{conf} } )
        {
            for my $conf ( @$conf )
            {
                my ( $host, $ip ) = each %$conf;
                $conf{$host} = [ @$ip ];
            }
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
