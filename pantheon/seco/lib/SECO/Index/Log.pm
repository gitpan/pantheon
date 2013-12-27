package SECO::Index::Log;

=head1 NAME

SECO::Index::Log

=head1 SYNOPSIS
 
 use SECO::Index::Log;

=cut

use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Spec;

use Hermes;
use MIO::TCP;
use Poros::Query;
use Vulcan::OptConf;

my ( %poros, %seco );
BEGIN
{
    %poros = Vulcan::OptConf->load()->dump( 'poros' );
    %seco = Vulcan::OptConf->load()->dump( 'seco' );
};

sub logto
{
    my %param = @_;
    my ( $code, $argv ) = @param{ qw( code argv ) };
    unshift @$argv, 'seco';
    my $range = Hermes->new();
    my @target = @{ $seco{index}{logtarget} || [] };

    return unless @target;

    my %result = MIO::TCP
        ->new( map { join ':', $_, $poros{port} } @target )
        ->run( input => Poros::Query->dump( +{ map { $_ => $param{$_} }
            qw( code argv )} ) );

#    die "poros fail: $result{error}" if $result{error};
    my %mesg;
    while ( my ( $type, $mesg ) = each %result )
    {
        while ( my ( $mesg, $node ) = each %$mesg )
        {
            map { $_ =~ s/:$poros{port}$// } @$node;
            $mesg =~ s/--- \d+\n$//;
            $node = $range->load( $node )->dump();
            if( $mesg )
            {
                $mesg{$type}{$node} = YAML::XS::Load( $mesg )
            }
            else
            {
                $mesg{$type}{$node} = '';
            }
        }
    }
    return wantarray ? %mesg : \%mesg;
}

1;
