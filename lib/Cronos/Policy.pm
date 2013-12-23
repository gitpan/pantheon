package Cronos::Policy;

use strict;
use warnings;

use Carp;
use DateTime;
use YAML::XS;

use Cronos::Period;

=head1 SYNOPSIS

 use Cronos::Policy;

 Cronos::Policy->new( $conf )->dump( $cache );

 my $policy = Cronos::Policy->load( $cache );
 my $now = time;
 my $level = 2;

 $policy->set( $now - 86400, $now + 86400 );

 my $who = $policy->get( $now, $level );
 my %list = $policy->list( $level );

=cut
sub new
{
    my $self = shift;
    $self->load( @_ );
}

=head1 METHODS

=head3 load( $path )

Load object from $path

=cut
sub load
{
    my $class = shift;
    croak "empty config" unless my @conf = YAML::XS::LoadFile shift;

    my $conf = $conf[0];
    return $conf if ref $conf eq ( $class = ref $class || $class );

    delete @$conf{ qw( duration level day ) };

    for my $conf ( @conf )
    {
        my $error = 'invalid definition: ' . YAML::XS::Dump $conf;
        croak $error unless $conf && ref $conf eq 'HASH';

        my @undef = grep { ! $conf->{$_} } qw( site period queue ); 
        croak $error . 'missing: ' . YAML::XS::Dump \@undef if @undef;

        map { croak $error . "$_: not ARRAY" if $conf->{$_}
            && ref $conf->{$_} ne 'ARRAY' } qw( queue level day );

        croak $error . 'invalid epoch' unless $conf->{epoch} = 
            Cronos->epoch( $conf->{epoch},
            DateTime::TimeZone->new( name => $conf->{timezone} || 'local' ) );

        $conf->{level} = { map { $_ => 1 } @{ $conf->{level} || [] } };
        $conf->{duration} =
            Cronos::Period->new( $conf->{duration} || '00:00 ~ 23:59' );
    }
    bless \@conf, $class;
}

=head3 dump( $path )

Dumps object to $path

=cut
sub dump
{
    my ( $self, $path ) =  splice @_;
    YAML::XS::DumpFile $path, $self if $path;
    return $self;
}

=head3 set( $begin, $end )

Sets the scope

=cut
sub set
{
    my $self = shift;
    my ( $begin, $end ) = map { ! ref $_ ? DateTime->from_epoch( epoch => $_ )
        : $_->isa( 'DateTime' ) ? $_ : croak 'invalid time input' } @_;

    for my $conf ( @$self )
    {
        my $cycle = $conf->{period} * @{ $conf->{queue} };
        my $epoch = DateTime->from_epoch
            ( epoch => $conf->{epoch}, time_zone => $conf->{timezone} );
        my $diff = int( ( $begin->epoch - $epoch->epoch )
            / ( $cycle * Cronos::DAY ) ) * $cycle;

        if ( $diff > 0 ) { $epoch->add( days => $diff ) }
        else { $epoch->subtract( days => $cycle - $diff ) }

        my ( $range, $event ) = $conf->{duration}->dump( $epoch, $end, %$conf );

        $conf->{event} = $event;
        $conf->{range} =
            $range->intersect( $range->new->load( $begin->epoch, $end->epoch ) )
    }
    return $self;
}

=head3 get( $time, $level )

Returns the event at $time for $level

=cut
sub get
{
    my ( $self, $time, $level ) = splice @_;

    for my $conf ( reverse @$self )
    {
        last unless my $range = $conf->{range};
        next if %{ $conf->{level} } && ! $conf->{level}{$level} 
            || ! defined $range->index( $time );

        my $i = int( ( $time - $conf->{epoch} ) / $conf->{period} /
            Cronos::DAY + $level ) % @{ $conf->{queue} };
        return { site => $conf->{site}, item => $conf->{queue}[$i] };
    }
    return undef;
}

=head3 list( $level )

Returns a HASH of events indexed by time for $level

=cut
sub list
{
    my ( $self, $level ) = splice @_;
    my $prev = { item => Cronos::NULL };
    my %list = map { $_ => 1 } map { @{ $_->{event} } } @$self;

    for my $time ( sort { $a <=> $b } keys %list )
    {
        my $conf = $self->get( $time, $level );

        if ( ! $conf || $conf->{item} eq $prev->{item} ) { delete $list{$time} }
        else { $prev = $list{$time} = $conf }
    }
    return wantarray ? %list : \%list;
}

1;
