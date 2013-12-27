use strict;
use warnings;
use FindBin qw( $Bin );

use lib "$Bin/lib";
use pantheon;

exit 0 unless my $pantheon = $ENV{PANTHEON};

my $root = "$pantheon/pantheon";
my $config = "$root/tools/.config";
my $daemon = "$root/tools/daemon";
my $cache = "$root/hermes/cache";

system "$^X $Bin/UPDATE $ARGV[0]";
system "mkdir -p $cache && touch $cache/current";
system "cp $config.example $config" unless -f $config;

exit 0 unless substr( $pantheon::VERSION, -1 ) % 2;
system "which svc tcpserver && $root/tools/daemon poros.proxy --kill --run";
exit 0;
