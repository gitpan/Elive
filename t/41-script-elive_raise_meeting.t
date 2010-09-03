#!perl
use strict;
use warnings;
use File::Spec;
use Test::More;
use Test::Exception;
use English qw(-no_match_vars);

use lib '.';
use t::Elive;

use Elive;
use Elive::Entity::Meeting;

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval "use Test::Script::Run";

if ( $EVAL_ERROR ) {
    my $msg = 'Test::Script::Run required to run scripts';
    plan( skip_all => $msg );
}

unless (${Test::Script::Run::VERSION} >= '0.04') {
    my $msg = "Test::Script::Run version (${Test::Script::Run::VERSION} < 0.04)";
    plan( skip_all => $msg );
} 

plan(tests => 74);

local ($ENV{TERM}) = 'dumb';

my $script_name = 'elive_raise_meeting';

#
# try running script with --help
#

do {
    my ( $result, $stdout, $stderr ) = run_script($script_name, ['--help'] );
    ok($stderr eq '', "$script_name --help: stderr empty");
    ok($stdout =~ m{usage:}ix, "$script_name --help: stdout =~ 'usage:...''");
};
#
# try with invalid option
#

do {
    my ( $result, $stdout, $stderr ) = run_script($script_name, ['--invalid-opt']);

    ok($stderr =~ m{unknown \s+ option}ix, "$script_name invalid option message");
    ok($stdout =~ m{usage:}ix, "$script_name invalid option usage");

};

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests',
	  70)
	unless $auth && @$auth && $auth->[0] && $auth->[1] && $auth->[2];

    my $meeting_name = 'test meeting, generated by t/41-script-elive_raise_meeting.t';

    my @meeting_args = (
	$auth->[0],
	-user => $auth->[1], -pass => $auth->[2],
	-name => $meeting_name,
	);

    my $meeting_response_re = qr{^created meeting: (.*?) with id (\d+)$}im;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth)
	or die "failed to connect?";

  MEETING_DEFAULTS:
    do {
	diag("*** TESTING MEETING DEFAULTS ****");
	my $time = time();
	my ( $result, $stdout, $stderr ) = run_script($script_name, \@meeting_args );

	ok($stderr eq '', "stderr empty");

	my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);

	ok($ret_meeting_name, "meeting name returned");
	ok($ret_meeting_id, "meeting id returned");

	unless ($ret_meeting_name && $ret_meeting_id) {
		die "unable to raise simple meeting - aborting";
	}

	ok($ret_meeting_name eq $meeting_name, 'echoed meeting name as expected');

	my $meeting;
	ok($meeting = Elive::Entity::Meeting->retrieve([$ret_meeting_id], connection => $connection), 'retrieve');

	unless ($meeting) {
	    die "unable to retrieve meeting: $ret_meeting_id - aborting";
	}

	ok($meeting->name eq $meeting_name, 'retrieved meeting name as expected');

	my $start = substr($meeting->start, 0, -3) + 0;
	my $end = substr($meeting->end, 0, -3) + 0;
	my $duration = $end - $start;

	diag sprintf("time=%d, start=%d, end=%d (duration: %d minutes)",
		     $time, $start, $end, $duration);

	ok ($start >= $time - 60 && $start <= $time + 16*60, "default start time within about 15 mins");


	ok($duration >= 9 * 60 && $duration <= 61 * 60 , "sensible default duration");

	lives_ok(sub {$meeting->delete}, 'deletion - lives');
    };

  BASIC_OPTIONS:
    do {
	diag("*** TESTING BASIC OPTIONS ****");
	my $weeks = 3;
	my $time = time();
	my $start_time = $time + 3600;
	my $end_time = $start_time + 1800;
	my @start = localtime($start_time);
	my @end   = localtime($end_time);

	my $start_str = sprintf("%04d-%02d-%02d %02d:%02d", $start[5]+1900, $start[4]+1, $start[3], $start[2], $start[1]);
	my $end_str = sprintf("%04d-%02d-%02d %02d:%02d", $end[5]+1900, $end[4]+1, $end[3], $end[2], $end[1]);
	my $meeting_pass = "test-".t::Elive::generate_id();

	my @basic_meeting_args = (
	    -occurs => "weeks=$weeks",
	    -start => $start_str,
	    -end   => $end_str,
	    -meeting_pass => $meeting_pass,
	    );

	my ( $result, $stdout, $stderr ) = run_script($script_name,
						      [@meeting_args,
						       @basic_meeting_args,
						      ] );

	ok($stderr eq '', "stderr empty");

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

	    ok($ret_meeting_name eq $meeting_name, "week $week: echoed meeting name as expected");

	    my $meeting;
	    ok($meeting = Elive::Entity::Meeting->retrieve([$ret_meeting_id], connection => $connection), "week $week: retrieve");

	    unless ($meeting) {
		die "unable to retrieve meeting: $ret_meeting_id - aborting";
	    }

	    if ($week == 1) {
		my $actual_start_time = substr($meeting->start, 0, -3);
		my $actual_end_time = substr($meeting->end, 0, -3);

		ok(abs($actual_start_time - $start_time) <= 120, "week $week: actual start time as expected");	
		ok(abs($actual_end_time - $end_time) <= 120, "week $week: actual end time as expected");	
	    }

	    ok($meeting->name eq $meeting_name, "week $week: retrieved meeting name as expected");
	    ok(do {grep {$_->meetingId eq $ret_meeting_id} @$meetings_with_this_password}, "week $week: meeting password as expected");

	    my $start = substr($meeting->start, 0 , -3);

	    if ($last_meeting_start) {
		ok(t::Elive::a_week_between($last_meeting_start, $start), sprintf('weeks %d - %d: meetings separated by a week (approx)', $week-1,$week));
	    }

	    $last_meeting_start = $start;

	    lives_ok(sub {$meeting->delete}, "week $week: deletion - lives");
	}

	ok ($week == $weeks, "expected number of meeting repeats ($weeks)");
    };

    my @flags = qw(invites private permissions raise_hands supervised);

    push (@flags, 'restricted')
	if 0;

  FLAGS_ON:
    do {
	diag("*** TESTING FLAGS ON ****");

	my @flags_on_args = (
	    map {'-'.$_} @flags
	    );

	my ( $result, $stdout, $stderr ) = run_script($script_name,
						      [@meeting_args,
						       @flags_on_args
						      ] );

	ok($stderr eq '', "stderr empty");

	my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);
	my $meeting;
	ok($meeting = Elive::Entity::Meeting->retrieve([$ret_meeting_id], connection => $connection), "meeting retrieve");

	unless ($meeting) {
	    die "unable to retrieve meeting: $ret_meeting_id - aborting";
	}

	foreach my $flag (@flags) {
	    my $result = _lookup_opt($meeting, $flag);

	    ok($result, "meeting -${flag} as expected");
	}

	lives_ok(sub {$meeting->delete}, "deletion - lives");

    };

  FLAGS_OFF:
    do {
	diag("*** TESTING FLAGS OFF ****");

	my @flags_off_args = (
	    map {'-no'.$_} @flags
	    );

	my ( $result, $stdout, $stderr ) = run_script($script_name,
						      [@meeting_args,
						       @flags_off_args
						      ] );

	ok($stderr eq '', "stderr empty");

	my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);
	my $meeting;
	ok($meeting = Elive::Entity::Meeting->retrieve([$ret_meeting_id], connection => $connection), "meeting retrieve");

	unless ($meeting) {
	    die "unable to retrieve meeting: $ret_meeting_id - aborting";
	}

	foreach my $flag (@flags) {
	    my $result = _lookup_opt($meeting, $flag);

	    ok(!$result, "meeting -no${flag} as expected");
	}

	lives_ok(sub {$meeting->delete}, "deletion - lives");

    };

  OPTIONS:
    do {
	diag("*** TESTING OPTIONS ****");

	my %option_values = (
	    boundary => [0, 15, 30],
	    max_talkers => [0, 1, 4],
	    recording => [qw{on off remote}],
	);

	foreach my $run (0,1,2) {

	    my @options;

	    foreach my $option (sort keys %option_values) {
		push (@options, '-'.$option => $option_values{$option}[$run]);
	    }

	    my ( $result, $stdout, $stderr ) = run_script($script_name,
						      [@meeting_args,
						       @options,
						      ] );

	    ok($stderr eq '', "stderr empty");

	    my ($ret_meeting_name, $ret_meeting_id) = ($stdout =~ $meeting_response_re);
	    my $meeting;
	    ok($meeting = Elive::Entity::Meeting->retrieve([$ret_meeting_id], connection => $connection), "meeting retrieve");

	    unless ($meeting) {
		die "unable to retrieve meeting: $ret_meeting_id - aborting";
	    }

	    foreach my $option (sort keys %option_values) {

		my $expected_value =  $option_values{$option}[$run];
		my $result = _lookup_opt($meeting, $option);
		
		ok($result eq $expected_value, "meeting run $run: -${option} eq $expected_value");
	    }

	    lives_ok(sub {$meeting->delete}, "deletion - lives");

	}
    }
};

########################################################################

sub _lookup_opt {
    my $meeting = shift;
    my $flag = shift;

    return $meeting->server_parameters->boundaryMinutes
	if $flag eq 'boundary';

    return $meeting->parameters->inSessionInvitation
	if $flag eq 'invites';

    return $meeting->server_parameters->fullPermissions
	if $flag eq 'permissions';

    return $meeting->parameters->maxTalkers
	if $flag eq 'max_talkers';

    return $meeting->parameters->raiseHandOnEnter
	if $flag eq 'raise_hands';

    return $meeting->parameters->recordingStatus
	if $flag eq 'recording';

    return $meeting->server_parameters->supervised
	if $flag eq 'supervised';

    return $meeting->$flag;
}
