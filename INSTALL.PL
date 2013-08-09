use strict;
use warnings;
use Tie::File;
use File::Basename;
use FindBin qw( $Bin );

our $INST = $ARGV[0];
our $PACK = basename( $Bin );

exit 0 unless our $ROOT = $ENV{ uc $PACK };
exit 0 unless our @INST = manifest();

munge() if $ENV{MUNGE_PERL};
install();
exit 0;

sub munge
{
    warn "Munging invocation perl path to $^X ..\n";
    for my $file ( map { `find $_ -type f` } @INST )
    {
        chomp $file;
        tie my ( @file ), 'Tie::File', $file;

        next unless @file && $file[0] =~ /#![^#]*perl(.*$)/o;
        $file[0] = "#!$^X$1";
        warn "$file\n";
        untie @file;
    }
}

sub install
{
    warn "Installing $PACK to $ROOT ..\n";
    system "mkdir -p $ROOT";
    system "tar -T ${INST}.in -X ${INST}.ex -cf - | ( cd $ROOT; tar xvf - )";
    map { system "cd $ROOT && sudo chown -R root:root $_" } @INST;
}

sub manifest
{
    my %list = ( ex => {}, in => {} );

    for my $path ( <> )
    {
        $path =~ s/#.*//;
        $path =~ s/^\s*//;
        $path =~ s/\s*$//;

        next if $path =~ /^$/;

        my $list = $path =~ s/^-\s*// ? $list{ex} : $list{in};
        map { $list->{$_} = 1 } glob $path;
    }

    map { delete $list{in}{$_} if $list{in}{$_} } keys %{ $list{ex} };

    for my $ext ( qw( in ex ) )
    {
        my @list = sort keys %{ $list{$ext} };
        open my $handle, '>', join '.', $INST , $ext;
        print $handle join( "\n", @list ), "\n";
        close $handle;

        $list{$ext} = \@list;
    }

    my @inst = @{ $list{in} };
    chomp @inst;
    return @inst;
}
