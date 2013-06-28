package pantheon;

use strict;
use warnings;

=head1 NAME

pantheon - A suite of cluster administration platforms

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';

=head1 MODULES

=head3 Argos

A monitoring platform

 Argos::Map.pm
 Argos::Reduce.pm
 Argos::Ctrl.pm
 Argos::Data.pm
 Argos::Path.pm
 Argos::Code.pm
 Argos::Conf.pm
 Argos::Conf::Map.pm
 Argos::Conf::Reduce.pm
 Argos::Code::Batch.pm
 Argos::Code::Map.pm
 Argos::Code::Reduce.pm

=head3 Ceres

A data collection platform

 Ceres::Sndr.pm
 Ceres::Rcvr.pm
 Ceres::DBI::Index.pm

=head3 Hermes

A cluster information management platform

 Hermes.pm
 Hermes::Range.pm
 Hermes::KeySet.pm
 Hermes::Cache.pm
 Hermes::Call.pm
 Hermes::DBI::Cache.pm
 Hermes::DBI::Root.pm

=head3 Janus

A maintenance platform

 Janus.pm
 Janus::Conf.pm
 Janus::Ctrl.pm
 Janus::Path.pm
 Janus::Log.pm
 Janus::Sequence.pm
 Janus::Sequence::Code.pm
 Janus::Sequence::Conf.pm

=head3 MIO

Multiplexed IO

 MIO::CMD.pm
 MIO::TCP.pm

=head3 Pan

A configuration management platform

 Pan::Conf.pm
 Pan::Macro.pm
 Pan::Node.pm
 Pan::Path.pm
 Pan::RCS.pm
 Pan::Repo.pm
 Pan::Transform.pm
 Pan::Util.pm

=head3 Poros

A plugin execution platform

 Poros.pm
 Poros::Path.pm
 Poros::Query.pm

=head3 Vulcan

A suite of utility modules

 Vulcan::Daemon.pm
 Vulcan::DirConf.pm
 Vulcan::OptConf.pm
 Vulcan::Logger.pm
 Vulcan::Phasic.pm
 Vulcan::ProcLock.pm
 Vulcan::SQLiteDB.pm
 Vulcan::SysInfo.pm
 Vulcan::Symlink.pm

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
