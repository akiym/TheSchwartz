# -*-perl-*-

use strict;
use warnings;

require 't/lib/db-common.pl';

use TheSchwartz;
use Test::More tests => ( ( 31 * 3 ) + ( 16 * 3 ) );

our $record_expected;
our $test2 = 0;

run_tests(
    47,
    sub {
        my $client = test_client( dbs => ['ts1'] );

        # Define that we want to use priority selection
        # limit batch size to 1 so we always process jobs in
        # priority order
        $client->set_prioritize(1);
        $TheSchwartz::FIND_JOB_BATCH_SIZE = 1;

        for ( 1 .. 10 ) {
            my $job = TheSchwartz::Job->new(
                funcname => 'Worker::PriorityTest',
                arg      => { num => $_ },
                ( $_ == 1 ? () : ( priority => $_ ) ),
            );
            my $h = $client->insert($job);
            ok( $h, "inserted job (priority $_)" );
        }

        $client->reset_abilities;
        $client->can_do("Worker::PriorityTest");

        Worker::PriorityTest->set_client($client);

        for ( 1 .. 10 ) {
            $record_expected = 11 - $_ == 1 ? undef : 11 - $_;
            my $rv = eval { $client->work_once; };
            ok( $rv, "did stuff" );
        }
        my $rv = eval { $client->work_once; };
        ok( !$rv, "nothing to do now" );

        teardown_dbs('ts1');

        # test we get in jobid order for equal priority RT #99075
        $test2 = 1;
        my $client2 = test_client( dbs => ['ts2'] );
        $client2->set_prioritize(1);
        $TheSchwartz::FIND_JOB_BATCH_SIZE = 1;

        $client2->reset_abilities;
        $client2->can_do("Worker::PriorityTest");

        Worker::PriorityTest->set_client($client2);

        # Define that we want to use priority selection
        # limit batch size to 1 so we always process jobs in
        # priority order
        $client2->set_prioritize(1);
        $TheSchwartz::FIND_JOB_BATCH_SIZE = 1;

        for ( 1 .. 5 ) {
            my $job = TheSchwartz::Job->new(
                funcname => 'Worker::PriorityTest',
                arg      => { num => $_ },
                priority => 5,
            );
            my $h = $client2->insert($job);
            ok( $h, "inserted job (priority $_)" );
        }

        for ( 1 .. 5 ) {
            $record_expected = $_;
            my $rv = eval { $client2->work_once; };
            ok( $rv, "did stuff 1-5" );
        }
        $rv = eval { $client2->work_once; };
        ok( !$rv, "nothing to do now 1-5" );

        teardown_dbs('ts2');
        $test2 = 0;
    }
);

############################################################################
package Worker::PriorityTest;
use base 'TheSchwartz::Worker';
use Test::More;

use strict;
my $client;
sub set_client { $client = $_[1]; }

sub work {
    my ( $class, $job ) = @_;
    my $priority = $job->priority;

    if ($main::test2) {
        ok( $job->jobid == $main::record_expected,
            "order by ID for same priority"
        );
    }
    else {
        ok( ( !defined($main::record_expected) && ( !defined($priority) ) )
                || ( $priority == $main::record_expected ),
            "priority matches expected priority"
        );
    }

    $job->completed;
}

sub keep_exit_status_for {
    20;
}    # keep exit status for 20 seconds after on_complete

sub grab_for {10}

sub max_retries {1}

sub retry_delay { my $class = shift; my $fails = shift; return 2**$fails; }

