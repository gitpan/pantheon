use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'pantheon',
    AUTHOR              => q{Kan Liu <kan@cpan.org>},
    VERSION_FROM        => 'lib/pantheon.pm',
    ABSTRACT_FROM       => 'lib/pantheon.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'threads' => 1.80,
        'Thread::Queue' => 2.12,
        'DBI' => 1.625,
        'DBD::SQLite' => 1.37,
        'YAML::XS' => 0.41,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'pantheon-*' },
);
