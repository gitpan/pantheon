package SECO::Engine::Access;

use base qw( SECO::Engine );

use strict;
use warnings;

local $/ = "\n";

our %LOG = map { $_ => "access.$_.log" } qw( qfedd qsrchd qsumd );
our %NRID = ( period => 60, sample => 60, mincnt => 1 );

sub nrid
{
    my ( $self, %param ) = splice @_;

    map { $param{$_} ||= $NRID{$_} } keys %NRID;

    my $log = $self->path( log => $LOG{qfedd} );
    my @log = `tail -n $param{sample} $log`;
    my $time = time;
    my @time = localtime $time;
  
    $time[5] += 1900;
    $time[4] += 1;

    my %nrid;
    my %time =
    (
        year => $time[5],
        tsfmt => sprintf '%02d-%02d %02d:%02d:%02d', @time[4,3,2,1,0],
    );

    while ( @log )
    {
        my $line = pop @log;
        next if $line !~ /nrid:(\S+)$/;
        last if $time - $param{period} > $self->logsse( $line, \%time ); 

        map { $nrid{$_} ++ } split ';', $1;
    }

    my @nrid = sort { $a <=> $b } keys %nrid;
    @nrid = grep { $nrid{$_} >= $param{mincnt} } @nrid if $param{mincnt} > 1;

    if ( $param{lookup} )
    {
        my %ini = $self->ini( 'qnet' );
        my %net = map { $_->[0] => $_ }
            map { [ split ':', $_ ] } @{ $ini{SERVER} };

        @nrid = map { $net{$_}[3] } @nrid;
    }

    return wantarray ? @nrid : \@nrid;
}

sub logsse
{
    my ( $self, $line, $time ) = splice @_;

    return 0 if $line !~ /^(\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})\s/;
    
    my $year = $time->{year};
    $year -= 1 if $1 gt $time->{tsfmt};
    $time = `date --date '$year-$1' +%s`; chomp $time;
    return 0 + $time;
}

1;
