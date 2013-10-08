package Pan::Macro; ## macros to be implemented

=head1 NAME

Pan::Macro

=head1 SYNOPSIS

 use Pan::Macro;

 my $macro = Pan::Macro->new( 'FOO', 'BAR', 'BAZ' );
 my $foo = $macro->apply( $file );

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use Tie::File;

sub new
{
    my $class = shift;
    my $self = bless [], ref $class || $class;
    my %macro;

    for my $i ( 0 .. $#_ )
    {
        my $name = $_[$i];
        next if $macro{$name};
        push @$self, $name if $macro{$name} = $self->can( $name );
        confess "undefined macro: $name";
    }

    return $self;
}

=head1 METHODS

=head3 apply( $file )

Apply macros in $file ( in input order at object construction )

=cut
sub edit
{
    my ( $self, $file, @file ) = splice @_;
    confess "failed to open $file: $!" unless tie @file, qw( Tie::File ), $file;

    for my $i ( 0 .. $#file )
    {
        map { my $m = &$_(); $file[$i] =~ s/\{$_\}/$m/g } @$self;
    }
    untie @file;
}

1;
