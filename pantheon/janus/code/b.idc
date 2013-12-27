### perl: janus/code/b.idc
### interleaf datacenter
use strict;
use File::Spec;

use Hermes;
use Vulcan::Sort;
use Vulcan::OptConf;

my ( $option, %seco );

BEGIN
{
    $option = Vulcan::OptConf->load();
    %seco = $option->dump( 'seco' );
}

use lib $seco{lib};
use SECO::Conf;

return sub
{
    my ( %param, @batch, %sort ) = @_;
    my $batch = $param{param}{batch} || 1;

    map { push @{ $sort{ ( split '\.', $_ )[-3] } }, $_ }
        Hermes->new( $option->dump( 'range' ) )->load( $param{target} )->list();

    for ( my $i = 0; %sort; $i ++ )
    {
        while ( my ( $dc, $node ) = each %sort )
        {
            push @{ $batch[$i] }, splice @$node, 0, $batch;
            delete $sort{$dc} unless @$node;
        }
    }
    return @batch;
};
