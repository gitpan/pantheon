package Cronos;

use strict;
use warnings;

use DateTime;

use constant { DAY => 86400, HOUR => 3600, MIN => 60, NULL => '' };

our $LTZ = DateTime::TimeZone->new( name => 'local' );
our $SEP = qr/[^:~\d\w]/,
our %RGX =
(
    year => qr/[2-9]\d{3}/,
    mon  => qr/1[0-2]|0?[1-9]/,
    day  => qr/3[01]|[1-2]\d|0?[1-9]/,
    hour => qr/2[0-3]|[0-1]?\d/,
    min  => qr/[0-5]?\d/,
);

=head1 METHODS

=head3 epoch( $date, $tz )

Returns seconds since epoch of expression $date with timezone $tz

=cut
sub epoch
{
    my ( $class, $date, $tz ) = splice @_;
    my %date = ( year => $1, month => $2, day => $3 ) if $date && ! ref $date
        && $date =~ qr/^\s*($RGX{year})$SEP($RGX{mon})$SEP($RGX{day})/;

    return undef unless %date;
    return DateTime->new( %date, time_zone => $tz || $LTZ )->epoch;
}

1;
