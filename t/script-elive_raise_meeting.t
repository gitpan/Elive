#!perl
use warnings; use strict;
use Test::More;
use Test::Fatal;

use File::Spec;
use English qw(-no_match_vars);
use version;

use lib '.';
use t::Elive;

use Elive;
use Elive::View::Session;
use Elive::Entity::Session;

eval "use Test::Script::Run 0.04 qw{:all}";

if ( $EVAL_ERROR ) {
    my $msg = 'Test::Script::Run 0.04+ required to run scripts';
    plan( skip_all => $msg );
}

plan(tests => 177);

our $t = Test::More->builder;

local ($ENV{TERM}) = 'dumb';

my $script_name = 'elive_raise_meeting';

#
# try running script with --help
#

do {
    my ( $return, $stdout, $stderr ) = run_script($script_name, ['--help'] );
    my $status = last_script_exit_code();
    is($status   => 0, "$script_name --help: zero exit status");
    is($stderr   => '', "$script_name --help: stderr empty");
    like($stdout => qr{usage:}ix, "$script_name --help: stdout =~ 'usage:...''");
};

#
# try with invalid option
#

do {
    my ( $return, $stdout, $stderr ) = run_script($script_name, ['--invalid-opt']);
    my $status = last_script_exit_code();

    isnt($status => 0, "$script_name invalid option: non-zero exit status");
    is($stdout   => '', "$script_name invalid option: stdout empty");
    like($stderr => qr{unknown \s+ option}ix, "$script_name invalid option: message");
    like($stderr => qr{usage:}ix, "$script_name invalid option: usage");

};

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 170)
	unless $auth && @$auth && $auth->[0] && $auth->[1] && $auth->[2];

    my $meeting_name = 'test meeting, generated by t/script-elive_raise_meeting.t';

    my $meeting_response_re = qr{^created meeting: (.*?) with id (\d+)$}im;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth)
	or die "failed to connect?";

    my $min_elm3_version =  '9.5.0';
    my $server_details = $connection->server_details;
    my $server_version = $server_details->version;

    my $have_elm3 = do {
	my $min_elm3_version_num = version->new($min_elm3_version)->numify;
	my $server_version_num = version->new($server_version)->numify;

	$server_version_num >= $min_elm3_version_num;
    };

    my $preload = Elive::Entity::Preload->upload(
	{
	    type => 'whiteboard',
	    name => 'test.wbd',
	    ownerId => $connection->login,
	    data => 'junkity junk junk',
	}, connection => $connection);

    foreach my $class (qw{Elive::View::Session Elive::Entity::Session}) {

	if ($class eq 'Elive::Entity::Session' && ! $have_elm3) {
	    diag "*** Skipping class $class for Elluminate Live! version $server_version < $min_elm3_version";
	    $t->skip("$class for Elluminate Live! version $server_version < $min_elm3_version")
		for (1..80);
	    next;
	}

	note "*** Testing class: $class";

	my @meeting_args = (
	    $auth->[0],
	    -user => $auth->[1], -pass => $auth->[2],
	    -name => $meeting_name,
	    -use  => $class,
	    );

      MEETING_DEFAULTS:
	do {
	    my $time = time();
	    my ( $return, $stdout, $stderr ) = run_script($script_name, \@meeting_args );
	    my $status = last_script_exit_code();

	    is( $status  => 0, "$script_name: zero exit status");
	    is($stderr   => '', "stderr empty");
	    like($stdout => $meeting_response_re, 'meeting response');
	    my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);

	    ok($ret_meeting_name, "meeting name returned");
	    ok($ret_meeting_id, "meeting id returned");

	    unless ($ret_meeting_name && $ret_meeting_id) {
		die "unable to raise simple meeting - aborting";
	    }

	    is($ret_meeting_name => $meeting_name, 'echoed meeting name as expected');

	    my $meeting;
	    ok($meeting = $class->retrieve($ret_meeting_id, connection => $connection), 'retrieve');

	    unless ($meeting) {
		die "unable to retrieve meeting: $ret_meeting_id - aborting";
	    }

	    is($meeting->name => $meeting_name, 'retrieved meeting name as expected');

	    my $start = substr($meeting->start, 0, -3) + 0;
	    my $end = substr($meeting->end, 0, -3) + 0;
	    my $duration = $end - $start;

	    ok ($start >= $time - 60 && $start <= $time + 16*60, "default start time within about 15 mins");


	    ok($duration >= 9 * 60 && $duration <= 61 * 60 , "sensible default duration");

	    is( exception {$meeting->delete} => undef, 'deletion - lives');
	};

      REPEATED_MEETING:
	do {
	    note ("\t-- Testing Basic Options");
	    my $weeks = 1;
	    my $time = time();
	    my $start_time = $time + 3600;
	    my $end_time = $start_time + 1800;
	    my @start = localtime($start_time);
	    my @end   = localtime($end_time);
	    my $cost_center = 'test-cost-center';
	    my $user_notes = 'test-user-notes';
	    my $moderator_notes = 'test-moderator-notes';
	    my $exit_url;
	    my $preload_id = $preload->preloadId;
	    my $invited_guest = 'Robert(bob@test.org)';

	    my $start_str = sprintf("%04d-%02d-%02d %02d:%02d", $start[5]+1900, $start[4]+1, $start[3], $start[2], $start[1]);
	    my $end_str = sprintf("%04d-%02d-%02d %02d:%02d", $end[5]+1900, $end[4]+1, $end[3], $end[2], $end[1]);
	    my $meeting_pass = "test-".t::Elive::generate_id();

	    my %basic_meeting_args = (
		-start => $start_str,
		-end   => $end_str,
		-meeting_pass => $meeting_pass,
		-cost_center  => $cost_center,
		-user_notes   => $user_notes,
		-moderator_notes  => $moderator_notes,
		-add_preload => $preload_id,
		);

	    if ($class eq 'Elive::View::Session') {
		$weeks = 3;
		$basic_meeting_args{-occurs} = "weeks=$weeks";
	    }
	    elsif ($class eq 'Elive::Entity::Session') {
		$exit_url = 'http://perlmonks.org';
		$basic_meeting_args{-exit_url} = $exit_url;
		note "$class - cant (yet) do repeating meetings";
	    }
	    else {
		die "unknown class: $class";
	    }

	    my ( $return, $stdout, $stderr ) = run_script($script_name,
							  [@meeting_args,
							   %basic_meeting_args,
							   $invited_guest,
							  ] );

	    if ($class eq 'Elive::Entity::Session') {
		is($stderr => '', "stderr empty ($class)");
	    }
	    else {
		like($stderr => qr{ignoring invited guests}, "std has 'ignoring invitied guests' warning");
	    }

	    my $last_meeting_start;
	    my $week;

	    my $resp = $stdout;
	    #
	    # meeting passwords are not returned directly. Instead we search
	    # for meetings that contain the password.
	    #
	    my $meetings_with_this_password = Elive::Entity::Meeting->list(filter => "password = '$meeting_pass'", connection => $connection);

	    while ($resp =~ s{$meeting_response_re}{}) {
		$week++;
		my $ret_meeting_name = $1;
		my $ret_meeting_id   = $2;

		ok($ret_meeting_name, "week $week: meeting name returned");
		ok($ret_meeting_id, "week $week: meeting id returned");

		is($ret_meeting_name => $meeting_name, "week $week: echoed meeting name as expected");

		my $meeting;
		ok($meeting = $class->retrieve($ret_meeting_id, connection => $connection), "week $week: retrieve");

		unless ($meeting) {
		    die "unable to retrieve meeting: $ret_meeting_id - aborting";
		}

		if ($week == 1) {
		    my $actual_start_time = substr($meeting->start, 0, -3);
		    my $actual_end_time = substr($meeting->end, 0, -3);

		    ok(abs($actual_start_time - $start_time) <= 120, "week $week: actual start time as expected");	
		    ok(abs($actual_end_time - $end_time) <= 120, "week $week: actual end time as expected");
		}

		is($meeting->cost_center => $cost_center, "week $week: cost_center as expected");
		is($meeting->user_notes => $user_notes, "week $week: user_notes as expected");
		is($meeting->moderator_notes => $moderator_notes, "week $week: moderator_notes as expected");

		is($meeting->name => $meeting_name, "week $week: retrieved meeting name as expected");

		is($meeting->redirectURL => $exit_url, "week $week: redirectURL as expected")
		    if $exit_url;

		my $meeting_preloads = $meeting->list_preloads;
		is_deeply([map {$_->preloadId} @$meeting_preloads] => [$preload_id], "Week $week - preload added");

		ok(do {grep {$_->meetingId eq $ret_meeting_id} @$meetings_with_this_password}, "week $week: meeting password as expected");

		my $start = substr($meeting->start, 0 , -3);

		if ($last_meeting_start) {
		    ok(t::Elive::a_week_between($last_meeting_start, $start), sprintf('weeks %d - %d: meetings separated by a week (approx)', $week-1,$week));
		}

		$last_meeting_start = $start;

		is( exception {$meeting->delete} => undef, "week $week: deletion - lives");
	    }

	    ok ($week == $weeks, "expected number of meeting repeats ($weeks)");
	};

	my @flags = qw(invites private permissions raise_hands supervised);

	push (@flags, qw{restricted follow_moderator all_moderators})
	    if $class eq 'Elive::Entity::Session';

      FLAGS_ON:
	do {
	    note ("\t-- Testing Flags On");

	    my @flags_on_args = (
		map {'-'.$_} @flags
		);

	    my ( $return, $stdout, $stderr ) = run_script($script_name,
							  [@meeting_args,
							   @flags_on_args
							  ] );

	    is($stderr => '', "stderr empty");
	    like($stdout => $meeting_response_re, 'meeting response');
	    my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);

	    my $meeting;
	    ok($meeting = $class->retrieve($ret_meeting_id, connection => $connection), "meeting retrieve");

	    unless ($meeting) {
		die "unable to retrieve meeting: $ret_meeting_id - aborting";
	    }

	    foreach my $flag (@flags) {
		my $result = $meeting->$flag;

		ok($result, "meeting -${flag} as expected");
	    }

	    is( exception {$meeting->delete} => undef, "deletion - lives");

	};

      FLAGS_OFF:
	do {
	    note ("\t-- Testing Flags Off");

	    my @flags_off_args = (
		map {'-no'.$_} @flags
		);

	    my ( $return, $stdout, $stderr ) = run_script($script_name,
							  [@meeting_args,
							   @flags_off_args
							  ] );

	    is($stderr => '', "stderr empty");

	    like($stdout => $meeting_response_re, 'meeting response');
	    my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);

	    my $meeting;
	    ok($meeting = $class->retrieve($ret_meeting_id, connection => $connection), "meeting retrieve");

	    unless ($meeting) {
		die "unable to retrieve meeting: $ret_meeting_id - aborting";
	    }

	    foreach my $flag (@flags) {
		my $result = $meeting->$flag;

		ok(!$result, "meeting -no${flag} as expected");
	    }

	    is( exception {$meeting->delete} => undef, "deletion - lives");

	};

      OPTIONS:
	do {
	    note ("\t-- Testing Options");

	    my %option_values = (
		boundary => [0, 15, 30],
		max_talkers => [0, 1, 4],
		recording => [qw{on off remote}],
		);

	    if ($class eq 'Elive::Entity::Session') {
		# elm3 only
		$option_values{max_cameras} = [3, 2, 1];
		$option_values{recording_resolution} = [qw(CG MG FC)];
		$option_values{profile} = [qw(none mod all)];
	    }	    

	    foreach my $run (0,1,2) {

		my @options;

		foreach my $option (sort keys %option_values) {
		    push (@options, '-'.$option => $option_values{$option}[$run]);
		}

		my ( $return, $stdout, $stderr ) = run_script($script_name,
							      [@meeting_args,
							       @options,
							      ] );

		is($stderr => '', "stderr empty");
		like($stdout => $meeting_response_re, 'meeting response');
		my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);

		my $meeting;
		ok($meeting = $class->retrieve($ret_meeting_id, connection => $connection), "meeting retrieve");

		unless ($meeting) {
		    die "unable to retrieve meeting: $ret_meeting_id - aborting";
		}

		foreach my $option (sort keys %option_values) {

		    my $expected_value =  $option_values{$option}[$run];
		    my $result = $meeting->$option;
		    
		    is($result => $expected_value, "meeting run $run: -${option}, $expected_value");
		}

		is( exception {$meeting->delete} => undef, "deletion - lives");

	    }
	}
    }

    $preload->delete;
}
