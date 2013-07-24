use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

our %PREREQ_PM =
(
    'DBI' => 1.625,
    'threads' => 1.80,
    'YAML::XS' => 0.41,
    'Test::More' => 0,
    'DBD::SQLite' => 1.37,
    'Thread::Queue' => 2.12,
);

WriteMakefile
(
    NAME          => 'pantheon',
    AUTHOR        => 'Kan Liu <kan@cpan.org>',
    VERSION_FROM  => 'lib/pantheon.pm',
    ABSTRACT_FROM => 'lib/pantheon.pm',
    PL_FILES      => {},
    PREREQ_PM     => \%PREREQ_PM, 
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean         => { FILES => 'pantheon-*' },
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ( LICENSE => 'perl' ) : () )
);
