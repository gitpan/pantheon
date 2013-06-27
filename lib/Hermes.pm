package Hermes;

=head1 NAME

Hermes - Cluster information interpreter. Extends Hermes::Range

=head1 SYNOPSIS

 use Hermes;

 my $a = Hermes->new( cache => '/database/file' );

 $a->load( 'foo{2~9}{??==*=={foo,bar}!!baz}.bar' );

 ## ... see base class for other methods ...

=cut
use strict;
use warnings;

use base qw( Hermes::Range );

=head1 QUERY

=head3 cluster

A I<cluster> query is expressed as a tuple of elements, corresponding
to columns of the cache table. See Hermes::DBI::Cache.

Such a query is made when an element is indicated by the I<select> symbol,
and the other three are given as query conditions, expressed by a I<condition>
symbol followed a range expression.  e.g. "{??==*=={foo,bar}!!baz}" may be
translated into the following SQL statement,

 "SELECT col1 FROM $TABLE WHERE col3 IN ('foo','bar') AND col4!='baz'"

=cut
use Hermes::DBI::Cache;

=head3 callabck

A I<callback> query is expressed as a callback symbol followed by the
callback name, and optionally, followed by a query condition.
See Hermes::Call.

e.g. "{%%foo!!bar,baz}" means get all elements returned by callback
I<foo>, expect those indexed by I<bar> and I<baz>.

Naturally, '*' in a query condition means 'any', i.e. I<no condition>.
And a query expression may be I<recursive>.

=cut
use Hermes::Call;

=head1 SYMBOLS

( in addition to those in the base class )

=head3 QUERY

 '??' : select
 '==' : in
 '!!' : not

=cut
$Hermes::Range::SYMBOL{QUERY} =
{
    select => '??', in => '==', 'not' => '!!', call => '%%'
};

sub new
{
    my ( $class, %path ) = splice @_;
    my ( $cache, $callback ) = @path{ qw( cache callback ) };
    my $self = bless Hermes::Range->new(), ref $class || $class;
    $self->{db} = Hermes::DBI::Cache->new( $cache ) if $cache;
    $self->{cb} = Hermes::Call->new( $callback ) if $callback;
    return $self;
}

=head1 GRAMMAR

( BNF rules additional to those in the base class )

=head3 complex

 '{' [ <expr> | <call> | <cluster> ] '}'

=cut
sub complex
{
    my $self = shift;
    my $token = $self->incr->token( '' );
    my $stage = ! $self->op( QUERY => 0 )
        ? 'expr' : $token eq 'call' ? $token : 'cluster';

    my $result = $self->$stage;

    die unless $self->token( 'close' );
    $self->incr;
    return $result;
}

=head3 complex

 <call_sym> <string> <query_cond>

=cut
sub call
{
    my $self = shift;
    my $result = Hermes::KeySet->new();
    my $name = $self->incr->token;
    my $cond = $self->incr->token( 'close' ) ? [] : $self->query_cond;

    $cond = [] unless $cond && ref $cond;
    return $result unless my $cb = $self->{cb};
    return $result->load( [ map { @$_ } $cb->run( $name, @$cond ) ] );
}

=head3 cluster
 
 [ <select_symbol> <query_cond> ** 3 ] |
 [ <query_cond> <select_symbol> <query_cond> ** 2 ] |
 [ <query_cond> ** 2 <select_symbol> <query_cond> ] |
 [ <query_cond> ** 3 <select_symbol> ]

=cut
sub cluster
{
    my $self = shift;
    my ( $result, $select, %cond ) = Hermes::KeySet->new();

    for my $col ( $self->{db}->column() )
    {
        next unless my $cond = $self->query_cond;
        if ( ref $cond ) { $cond{$col} = $cond } else { $select = $col }
    }

    return $result unless my $db = $self->{db};
    return $result->load( [ map { @$_ } $db->select( $select, %cond ) ] );
}

=head3 query_cond

 <condition_symbol> <expr>

=cut
sub query_cond
{
    my $self = shift;
    die unless my $op = $self->op( QUERY => 1 );
    return $op if $op eq 'select';

    my $range = $self->expr;
    return $range->has( '*' ) ? undef : [ ( $op eq 'in' ), $range->list ];
}

1;
