package Hermes::Call;

=head1 NAME

Hermes::Call - callback interface to Hermes

=head1 SYNOPSIS

 use Hermes::Call;

 my $cb = Hermes::Call->new( '/callback/dir' );

 my $result = $cb->run( 'foo' );

=cut
use strict;
use warnings;
use Carp;

use File::Spec;
use File::Basename;

=head1 CALLBACKS

Each callback must return a CODE that returns a HASH of ARRAY when invoked.

=cut
sub new
{
    my ( $class, $path, %self ) = splice @_, 0, 2;

    confess "undefined path" unless $path;
    $path = readlink $path if -l $path;
    confess "invalid path $path: not a directory" unless -d $path;

    for my $path ( grep { -f $_ } glob File::Spec->join( $path, '*' ) )
    {
        my $error = "invalid code: $path";
        my $name = File::Basename::basename( $path );

        $self{$name} = do $path;
        confess "$error: $@" if $@;
    }
    bless \%self, ref $class || $class;
}

=head1 METHODS

=head3 run( $name, @cond )

Run callback I<$name>, then select results by I<@cond>, if any. The first
value in @cond indicates positive or negative selection. The rest of @cond
are keys by which to select.

All values are selected if no @cond is given.

=cut
sub run
{
    my ( $self, $name ) = splice @_, 0, 2;
    return () unless my $code = $self->{$name};

    my $result = &$code() || {};
    return () unless ref $result eq 'HASH';

    delete @$result{ splice @_ } unless shift @_;
    grep { $_ && ref $_ eq 'ARRAY' } @_ ? @$result{@_} : values %$result;
}

1;
