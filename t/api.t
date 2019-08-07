# $Id$
# -*-perl-*-

use strict;
use warnings;

require './t/lib/db-common.pl';

use TheSchwartz;
use Test::More tests => 58 * 3;

run_tests(
    58,
    sub {
        foreach my $pfx ( "", "testprefix_" ) {

            my $client = test_client(
                dbs      => ['ts1'],
                dbprefix => $pfx,
            );

            my $handle;

            $handle = $client->insert( "feedmajor",
                { scoops => 2, with => [ 'cheese', 'love' ] } );
            isa_ok $handle, 'TheSchwartz::JobHandle', "inserted job";
            is( $handle->is_pending,  1,     "job is still pending" );
            is( $handle->exit_status, undef, "job hasn't exitted yet" );

            # to give to javascript, perl, etc...
            my $hstr = $handle->as_string;    # <digestofdsn>-<jobid>
            ok( $hstr, "handle stringifies" );

            my $job = $handle->job;
            isa_ok $job, 'TheSchwartz::Job';
            is $job->funcname, 'feedmajor',
                'handle->job gives us the right job';
            cmp_ok $job->insert_time, '>', 0, 'insert_time is non-zero';

            # getting a handle object back
            my $hand2 = $client->handle_from_string($hstr);
            ok( $hand2, "handle recreated from stringified version" );
            is( $handle->is_pending,  1,     "job is still pending" );
            is( $handle->exit_status, undef, "job hasn't exitted yet" );

            $job = $handle->job;
            isa_ok $job, 'TheSchwartz::Job';
            is $job->funcname, 'feedmajor',
                'recreated handle gives us the right job';

            # grab an job by ID.
            my $id   = $job->jobid;
            my @jobs = $client->list_jobs(
                { funcname => 'feedmajor', jobid => $id } );
            is( scalar @jobs,    1,   'one job' );
            is( $jobs[0]->jobid, $id, 'expected jobid' );

            $job = TheSchwartz::Job->new(
                funcname  => 'feedmajor',
                run_after => time() + 60,
                priority  => 7,
                arg       => { scoops => 2, with => [ 'cheese', 'love' ] },
                coalesce  => 'major',
                jobid     => int rand(5000),
            );
            ok($job);

            $handle = $client->insert($job);
            isa_ok $handle, 'TheSchwartz::JobHandle';

            # inserting multiple at a time in scalar context
            {
                my $job1 = TheSchwartz::Job->new( funcname => 'feedmajor' );
                my $job2 = TheSchwartz::Job->new( funcname => 'feedmajor' );
                my $rv = $client->insert_jobs( $job1, $job2 );
                is( $rv, 2, "inserted two jobs" );
            }

            # inserting multiple at a time in list context
            {
                my $job1 = TheSchwartz::Job->new( funcname => 'feedmajor' );
                my $job2 = TheSchwartz::Job->new( funcname => 'feedmajor' );
                my @handles = $client->insert_jobs( $job1, $job2 );
                is( scalar @handles, 2, "inserted two jobs" );
                isa_ok $handles[0], 'TheSchwartz::JobHandle',
                    "got job handle";
            }

            # inserting with a regular scalar arg
            {
                $job = TheSchwartz::Job->new(
                    funcname => 'feedmajor',
                    arg => "gruel that's longer than 11 bytes, for sure!",
                );
                ok($job);
                $handle = $client->insert($job);
                isa_ok $handle, 'TheSchwartz::JobHandle';

                my $same = $client->lookup_job( $handle->as_string );
                ok $same;
                isa_ok $same, 'TheSchwartz::Job';
                is $same->handle->as_string, $handle->as_string;

            }

            ## Just test that handles for unknown database croak with an explicit message
            {
                eval { $client->lookup_job( ( "6a" x 16 ) . "-666" ) };
                ok $@
                    && unlike( $@, qr/No Driver/ )
                    && like( $@, qr/database.*hash/ );
            }

            # inserting multiple with wrong method fails
            eval {
                my $job1 = TheSchwartz::Job->new( funcname => 'feedmajor' );
                my $job2 = TheSchwartz::Job->new( funcname => 'feedmajor' );
                my @handles = $client->insert( $job1, $job2 );
            };
            like( $@, qr/multiple jobs with method/, "used wrong method" );

            # insert multiple that fail
            {
                my $job1 = TheSchwartz::Job->new(
                    funcname => 'feedmajor',
                    uniqkey  => 'u1'
                );
                my $job2 = TheSchwartz::Job->new(
                    funcname => 'feedmajor',
                    uniqkey  => 'u1'
                );
                my @handles = $client->insert_jobs( $job1, $job2 );
                is( scalar @handles, 0, "failed to insert anything" );
            }

            teardown_dbs('ts1');
        }
    }
);

done_testing();

