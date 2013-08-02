package Vulcan::SysInfo;

=head1 NAME

Vulcan::SysInfo - Get various system statistics through sar, df, etc.

=head1 SYNOPSIS
 
 use Vulcan::SysInfo;

 my $sar = Vulcan::SysInfo->new( interval => 6 );

 my %info = $sar->info;
 my $stable = $sar->eval( 'MISC{data}{uptime} > 86400 * 1000' );

=cut
use strict;
use warnings;
use Carp;

use constant { KEY => 'MISC', VAL => 'data', INTERVAL => 6 };

our $REGEX = qr/\{ (\w+) \}\{ ([^{}]+) \}\{ ([^{}]+) \}/x;

sub new
{
    local $/ = "\n";
    my ( $class, %self ) = splice @_;
    my @stat =
    (
        [
            [ qw( time uptime idle ) ],
            [ time, split /\s+/, `cat /proc/uptime` ],
        ]
    );

    $self{interval} ||= INTERVAL;
    confess "open: $!" unless open my $cmd, "sar -A $self{interval} 1 |";

    my ( $flip, $flop, @data, %legend );

    while ( my $line = <$cmd> ) ## sar
    {
        $flip = $line =~ s/^Average:\s+//;
        $flop = $flip if $flip;
        next unless $flop;

        if ( length $line > 1 ) { push @data, [ split /\s+/, $line ] }
        else { $flop = $flip; push @stat, [ splice @data ] }
    }

    push @stat, [ splice @data ] if @data;

    for ( '-l', '-i' ) ## df: size and inode
    {
        for my $df ( map { [ ( split /\s+/, $_, 7 )[ 5, 1..4 ] ] } `df $_` )
        {
            map { $_ = $1 if $_ =~ /(\d+)%/ } @$df;
            push @data, $df;
        }

        $data[0][0] = 'DF';
        push @stat, [ splice @data ];
    }

    for my $stat ( @stat )
    {
        my $legend = shift @$stat;
        map { $_ =~ s/^%/pct_/; $_ =~ s/%$/_pct/ } @$legend;

        if ( $legend->[0] !~ /^[A-Z]+$/ )
        {
             unshift @$legend, KEY;
             unshift @{ $stat->[0] }, VAL;
        }

        my $type = shift @$legend;
        push @{ $legend{$type} }, @$legend;
        map { push @{ $self{metric}{$type}{ shift @$_ } }, @$_ } @$stat;
    }

    if ( `which ethtool` ) ## ethtool: speed
    {
        while ( my ( $iface, $data ) = each %{ $self{metric}{IFACE} } )
        {
            my $info = `ethtool $iface | grep Speed`;
            push @$data, $info && $info =~ /:\s(\d+\D+)\b/ ? $1 : '-'
        }

        push @{ $legend{IFACE} }, 'speed';
    }

    for my $type ( keys %legend )
    {
        my $i = 0;
        map { $self{legend}{$type}{$_} = $i ++ } @{ delete $legend{$type} };
    }

    bless \%self, ref $class || $class;
}

=head1 METHODS

=head3 info( $type )

Returns data of $type if $type is specified. Otherwise returns I<record>
and I<legend> indexed by I<type>.

=cut
sub info
{
    my ( $self, $type ) = splice @_;
    my ( $legend, $metric ) = @$self{ qw( legend metric ) };
    my %info;

    if ( defined $type && ( $legend = $legend->{$type} ) )
    {
        while ( my ( $key, $data ) = each %{ $metric->{$type} } )
        {
            map { $info{$key}{$_} = $data->[ $legend->{$_} ] } keys %$legend;
        }
    }
    else
    {
        for $type ( keys %$legend )
        {
            $info{$type}{legend} = [ sort keys %{ $legend->{$type} } ];
            $info{$type}{record} = [ sort keys %{ $metric->{$type} } ];
        }
    }
    return wantarray ? %info : \%info;
}

=head3 eval( $test )

Evaluate a test, Returns $test when true, undef otherwise.

=cut
sub eval
{
    my ( $self, $test ) = splice @_;
    my ( $legend, $metric ) = @$self{ qw( legend metric ) };

    while ( $test =~ /$REGEX/g )
    {
        return undef unless my $value = $metric->{$1}{$2};
        return undef unless my $index = $legend->{$1}{$3};
        return undef unless defined ( $value = $value->[$index] );

        $test =~ s/$REGEX/$value/;
    }
    return eval $test ? $test : undef;
}

1;
