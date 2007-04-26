# $Id: Error.pm 101 2006-08-23 21:22:49Z bradfitz $

package TheSchwartz::Error;
use strict;
use base qw( Data::ObjectDriver::BaseObject );

__PACKAGE__->install_properties({
               columns     => [ qw( jobid funcid message error_time ) ],
               datasource  => 'error',
           });

1;
