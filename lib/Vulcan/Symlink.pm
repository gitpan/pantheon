package Vulcan::Symlink;

=head1 NAME

Vulcan::Symlink - manipulate symbolic links

=cut
use strict;
use warnings;

use Cwd;
use Carp;
use File::Spec;

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
    map { confess "$_ not defined" unless defined $self{$_} } qw( link root );
    $self{prev} = "$self{link}.$ROLLBACK";
    bless \%self, ref $class || $class;
}

sub make
{
    my ( $self, %link ) = splice @_;
    my ( $path, $chown ) = @link{ qw( path chown ) };
    my ( $link, $prev ) = $self->path( @$self{ qw( link prev ) } );

    if ( defined $path )
    {
        $path = $self->path( $path );
        $self->syscmd( "ln -s $path $prev" ) unless -l $prev;
        $self->syscmd( "mv $link $prev; ln -s $path $link" )
            if $path ne $self->read();
    }
    else
    {
        $path = $self->path();
        $self->syscmd( "mv $prev $link" )
            if -l $prev && $self->read( $self->{prev} );
    }

    if ( $< ) { }
    elsif ( $chown ) { $self->syscmd( "chown -h $chown $link" ) }
    elsif ( -e $path ) { chown( ( stat $path )[4,5], $link ) }
    return $self;
}

sub check
{
    my $self = shift;
    my %link =
    (
        curr => [ $self->{link} => $self->read() ],
        prev => [ $self->{prev} => $self->read( $self->{prev} ) ],
    );
    return wantarray ? %link : \%link;
}

sub read
{
    my $self = shift;
    my @link = map { -l $_ ? readlink $_ : '' } $self->path( @_ );
    wantarray ? @link : shift @link;
}

sub path
{
    my $self = shift;
    my @path = map { File::Spec->file_name_is_absolute( $_ ) ? $_ :
        File::Spec->join( $self->{root}, $_ ) } @_ ? @_ : $self->{link};
    wantarray ? @path : shift @path;
}

sub syscmd
{
    my ( $self, $cmd ) = splice @_;
    confess "failed to $cmd" if system $cmd;
}

1;
