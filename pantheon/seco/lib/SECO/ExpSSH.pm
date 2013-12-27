package SECO::ExpSSH;

use base qw( SECO );

use strict;
use warnings;
use Expect;

our $TIMEOUT = 20;
our $SSH = 'ssh -o StrictHostKeyChecking=no -c blowfish';
our $DOMAIN = $SECO::DOMAIN;

sub new
{
    my $class = shift;
    bless { zone => { @_ } }, ref $class || $class;
}

sub conn
{
    my ( $self, $host, $user, $pass, $sudo, $home ) = splice @_;

    return unless $host = $self->host( $host );

    my $exp = Expect->new();
    my $ssh = "$SSH -t -l $user $host";
    my $prompt = '::sudo::';

    $pass .= "\n" if $pass !~ /\n$/;
    $home ||= '';
    $ssh .= " sudo -p '$prompt' su $home $sudo" if $sudo;

    $SIG{WINCH} = sub
    {
        $exp->slave->clone_winsize_from( \*STDIN );
        kill WINCH => $exp->pid if $exp->pid;
        local $SIG{WINCH} = $SIG{WINCH};
    };

    $exp->slave->clone_winsize_from( \*STDIN );
    $exp->spawn( $ssh );
    $exp->expect
    ( 
        $TIMEOUT, 
        [ qr/assword: *$/ => sub { $exp->send( $pass ); exp_continue; } ],
        [ qr/[#\$%] $/ => sub { $exp->interact; } ],
        [ qr/$prompt$/ => sub { $exp->send( $pass ); $exp->interact; } ],
    );
}

sub host
{
    my ( $self, $host ) = splice @_;
    my $zone = $self->{zone};

    return $host unless $host && $host !~ qr/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
    $host =~ s/$DOMAIN$//;

    my ( @host, @list ) = split '\.', $host;

    if ( @host == 1 )
    {
        while ( my ( $z, $zone ) = each %$zone )
        {
            push @list, map { "$host.$z.$_" } @$zone;
        }
    }
    elsif ( @host == 2 && ( $zone = $zone->{ $host[1] } ) )
    {
        @list = map { join '.', @host, $_ } @$zone;
    }
    else
    {
        @list = $host;
    }

    @host = ();

    for my $host ( @list )
    {
        $host .= $DOMAIN;
        push @host, $host unless system "host $host > /dev/null";
    }

    return shift @host if @host < 2;

    @list = map { sprintf "[ %d ] %s", $_ + 1, $host[$_] } 0 .. $#host; 
    print STDERR join "\n", @list, "please select: [ 1 ] ";

    my $i = <STDIN>; chop $i; $i = $i && $i =~ /(\d+)/ && $1 <= @host ? $1 : 1;
    return $host[ $i - 1 ];
}

1;
