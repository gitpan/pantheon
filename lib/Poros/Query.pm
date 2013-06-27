package Poros::Query;

=head1 NAME

Poros::Query - Poros query 

=head1 SYNOPSIS

 use Poros::Query;

 my $query = Poros::Query->dump( \%query ); ## scalar ready for transport

 my $code = Poros::Query->load( $query );

 print $code->yaml();

 my $result = $code->run( code => '/code/dir', run => '/run/dir' );

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Spec;
use Compress::Zlib;

=head1 METHODS

=head3 dump( $query )

Returns a scalar dumped from input HASH.

=cut
sub dump
{
    my ( $class, $query ) = splice @_;

    confess "invalid query" unless $query
        && ref $query eq 'HASH' && defined $query->{code};

    return Compress::Zlib::compress( YAML::XS::Dump $query );
}

=head3 load( $query )

Inverse of dump().

=cut
sub load
{
    my ( $class, $query ) = splice @_;
    my %self;

    die "invalid $query\n" unless
        ( $self{yaml} = Compress::Zlib::uncompress( $query ) )
        && eval { $query = YAML::XS::Load $self{yaml} }
        && ref $query eq 'HASH' && ( $self{code} = delete $query->{code} );

    my $user = delete $query->{user};

    if ( ! $< && $user && $user ne ( getpwuid $< )[0] )
    {
        die "invalid user $user\n" unless my @pw = getpwnam $user;
        my @user = map { sprintf '%d', $_ } @pw[2,3];
        ( $<, $>, $(, $) ) = ( @user[0,0,1], join ' ', @user[1,1] );
    }

    bless { %self, query => $query }, ref $class || $class;
}

=head3 run( %path )

Run code in $path{code}. If code name is postfixed with '.mx',
run code in mutual exclusion mode.

=cut
sub run
{
    my ( $self, %path ) = @_;
    my ( $code, $query ) = @$self{ qw( code query ) };

    die "already running $code\n" if ( $code =~ /\.mx$/ ) && !
        Vulcan::ProcLock->new( File::Spec->join( $path{run}, $code ) )->lock();

    die "invalid code\n" unless
        -f ( $code = File::Spec->join( $path{code}, $code ) )
        && ( $code = do $code ) && ref $code eq 'CODE';

    &$code( %$query );
}

=head3 yaml()

Return query in YAML.

=cut
sub yaml
{
    my $self = shift;
    return $self->{yaml};
}

1;
