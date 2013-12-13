use strict;
use warnings;
use FindBin qw( $Bin );

use lib "$Bin/lib";
use pantheon;

my $pantheon = "$ENV{PANTHEON}/pantheon";
my $daemon = "$pantheon/tools/daemon";
my $cache = "$pantheon/hermes/cache";

system "$^X $Bin/UPDATE $ARGV[0]";
system "mkdir -p $cache && touch $cache/current";

exit 0 unless substr( $pantheon::VERSION, -1 ) % 2;
exit 1 if system "which svc";

system "which tcpserver && $pantheon/tools/daemon poros.proxy --run";
