package Pan::Util;

use strict;
use warnings;
use Carp;

use Pan::Macro;

=head1 METHODS 

=head3 fmv( $src, $dst, %option )

Move regular file I<$src> to I<$dst>.  The following may be defined in
I<%option>, which are be apply to $src I<before> moving $src to $dst.

 patch : path of patch
 macro : list of macros to replace
 chown : ownership
 chmod : mode

When I<chown> and I<chmod> are unspecified, and I<$dst> already exists,
ownership and mode of $dst are assumed for I<$src>.

=cut
sub fmv
{
    my ( $class, $src, $dst, %option ) = splice @_;

    confess "$src is not a regular file" unless -f $src;
    $dst = readlink if -l $dst;

    my ( $mode, $uid, $gid ) = ( stat $dst )[2,4,5] if my $exist = -e $dst;
    my $error = "$src -> $dst: failed to";

    if ( my $patch = $option{patch} )
    {
        confess "$error patch $patch" if system( "patch $src < $patch" );
    }

    if ( my $macro = $option{macro} )
    {
        Pan::Macro->new( ref $macro ? @$macro : $macro )->apply( $src );
    }

    if ( my $chown = $option{chown} )
    {
        confess "$error chown $chown" if system( "chown $chown $src" );
    }
    elsif ( $exist )
    {
        chown $uid, $gid, $src;
    }

    if ( my $chmod = $option{chmod} )
    {
        confess "$error chmod $chmod" if system( "chmod $chmod $src" );
    }
    elsif ( $exist )
    {
        chmod $mode, $src;
    }

    if ( $src ne $dst )
    {
        confess "$error mv" if system( "mv $src $dst" );
    }
}

1;
