use strict;
use warnings;
use Tie::File;
use File::Basename;

exit 0 unless my $dir = $ENV{PANTHEON};
exit 0 unless my @install = `cat $ARGV[0]`; 

chomp @install;

if ( $ENV{MUNGE_PERL} )
{
    for my $file ( `find @install -type f` )
    {
        chomp $file;
        tie my ( @file ), 'Tie::File', $file;

        next unless @file && $file[0] =~ /#![^#]*perl(.*$)/o;
        $file[0] = "#!$^X$1";
        warn "$file\n";
        untie @file;
    }
}

my $mkdir = "mkdir -p $dir";
my $untar = "tar xvf - )";
my $tar = "tar cf - @install | ( cd $dir; ";

map { $_ = "sudo $_" } $mkdir, $untar unless canwrite( $dir );

system( $mkdir );
system( $tar . $untar );
system( "cd $dir && sudo chown -R root:root @install" );

sub canwrite
{
    my $dir = shift;
    $dir = dirname( $dir ) while ! -e $dir;
    return -w $dir;
}
