package pantheon;

use strict;
use warnings;

=head1 NAME

pantheon - A suite of cluster administration tools and platforms

=cut
our $VERSION = '0.15';

=head1 MODULES

=head3 Hermes

A cluster information management platform

 Hermes
 Hermes::Range
 Hermes::KeySet
 Hermes::Cache
 Hermes::Call
 Hermes::DBI::Cache
 Hermes::DBI::Root

=head3 Argos

A monitoring platform

 Argos::Map
 Argos::Reduce
 Argos::Ctrl
 Argos::Data
 Argos::Path
 Argos::Code
 Argos::Conf
 Argos::Conf::Map
 Argos::Conf::Reduce
 Argos::Code::Batch
 Argos::Code::Map
 Argos::Code::Reduce

=head3 Janus

A maintenance platform

 Janus
 Janus::Conf
 Janus::Ctrl
 Janus::Path
 Janus::Log
 Janus::Sequence
 Janus::Sequence::Code
 Janus::Sequence::Conf

=head3 MIO

Multiplexed IO

 MIO::CMD
 MIO::TCP

=head3 Poros

A plugin execution platform

 Poros
 Poros::Path
 Poros::Query

=head3 Pan

A configuration management platform

 Pan::Conf
 Pan::Macro
 Pan::Node
 Pan::Path
 Pan::RCS
 Pan::Repo
 Pan::Transform
 Pan::Util

=head3 Ceres

A data collection platform

 Ceres::Sndr
 Ceres::Rcvr
 Ceres::DBI::Index

=head3 Vulcan

A suite of utility modules

 Vulcan::Daemon
 Vulcan::DirConf
 Vulcan::OptConf
 Vulcan::Logger
 Vulcan::Phasic
 Vulcan::ProcLock
 Vulcan::SQLiteDB
 Vulcan::SysInfo
 Vulcan::Symlink
 Vulcan::Mrsync
 Vulcan::Cruft
 Vulcan::Grep
 Vulcan::Sudo

=head1 AUTHOR

Kan Liu, C<< <kan at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Kan Liu.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
