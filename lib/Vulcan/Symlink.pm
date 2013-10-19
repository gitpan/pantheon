package Vulcan::Symlink;

=head1 NAME

Vulcan::Symlink - manipulate symbolic links

=cut
use strict;
use warnings;

use Carp;
use Cwd;

our $ROLLBACK = 'rb';

=head1 SYNOPSIS

 use Vulcan::Symlink;
 
 my $link = Vulcan::Symlink->new
 (
     link => 'foo.bar',
     root => '/foo/bar', ## optional
 );

 my %link = $link->make( path => 'foo.real', chown => 'web:web' )->check;

=cut
sub new
{
    my ( $class, %self ) = splice @_;

    confess 'link not defined' unless defined $self{link};

    $self{rb} = "$self{link}.$ROLLBACK";
    $self{cwd} = getcwd();
    $self{root} = $self{cwd} unless defined $self{root};

    bless \%self, ref $class || $class;
}

sub make
{
    my ( $self, %link ) = splice @_;
    my ( $link, $rb ) = @$self{ 'link', 'rb' };
    my ( $path, $chown ) = @link{ 'path', 'chown' };

    my $curr = $self->readlink;
    my $prev = $self->readlink( $rb );

    return $self unless defined $path;

    if ( $path ne $curr )
    {
        $self->syscmd( "mv $link $rb" ) if length $curr;
        $self->syscmd( "ln -s $path $link" );
    }

    if ( $< ) { }
    elsif ( $chown ) { $self->syscmd( "chown -h $chown $link" ) }
    elsif ( -e $path ) { chown( ( stat $path )[4,5], $link ) }

    $self->chdir();
    return $self;
}

sub check
{
    my $self = shift;
    my %link = 
    ( 
        current => [ $self->{link} => $self->readlink() ],
        rollback => [ $self->{rb} => $self->readlink( $self->{rb} ) ],
    );
    $self->chdir();
    return wantarray ? %link : \%link;
}

sub readlink
{
    my $self = shift;
    my $link = @_ ? shift : $self->{link};

    $self->chdir( 'root' );
    return '' unless -e $link;
    $link = -l $link ? readlink $link : confess "$link is not a symlink";
}

sub chdir
{
    my $self = shift;
    my $dir = $self->{ @_ ? shift : 'cwd' };
    confess "failed to cd $dir" unless chdir $dir;
}

sub syscmd
{
    my ( $self, $cmd ) = splice @_;
    confess "failed to $cmd" if system $cmd;
}

sub DESTROY
{
    my $self = shift;
    $self->chdir();
    %$self = ();
}

1;
