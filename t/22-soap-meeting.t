#!perl
use warnings; use strict;
use Test::More tests => 36;
use Test::Exception;

use lib '.';
use t::Elive;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Entity::Meeting' );
    use_ok( 'Elive::Entity::MeetingParameters' );
    use_ok( 'Elive::Entity::ServerParameters' );
    use_ok( 'Elive::Entity::ParticipantList' );
};

my $class = 'Elive::Entity::Meeting' ;

SKIP: {

    my %result = t::Elive->auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'no test connection specified',
	31)
	unless $auth;

    Elive->connect(@$auth);

    my %meeting_str_data = (
	name => 'test meeting, generated by t/22-soap-meeting.t',
	facilitatorId => Elive->login->userId,
	password => 'test', # what else?
    );

    my $meeting_start = time();
    my $meeting_end = $meeting_start + 900;

    $meeting_start .= '000';
    $meeting_end .= '000';

    my %meeting_int_data = (
	start =>  $meeting_start,
	end => $meeting_end,
	privateMeeting => 1,
	
    );

    my ($meeting) = $class->insert({%meeting_int_data, %meeting_str_data});

    isa_ok($meeting, $class, 'meeting');

    foreach ('name') {
	#
	# returned record doesn't contain password
	ok($meeting->$_ eq $meeting_str_data{$_}, "meeting $_ eq $meeting_str_data{$_}");
    }

    foreach (keys %meeting_int_data) {
	ok($meeting->$_ == $meeting_int_data{$_}, "meeting $_ == $meeting_int_data{$_}");
    }

    my %parameter_str_data = (
	costCenter => 'testing',
	moderatorNotes => 'test moderator notes',
	userNotes => 'test user notes',
	recordingStatus => 'remote',
    );
    
    my %parameter_int_data = (
	raiseHandOnEnter => 1,
	maxTalkers => 3,
	);

    my $meeting_params = Elive::Entity::MeetingParameters->retrieve([$meeting->meetingId]);

    isa_ok($meeting_params, 'Elive::Entity::MeetingParameters', 'meeting_params');

    $meeting_params->update({%parameter_str_data, %parameter_int_data});

    foreach (keys %parameter_str_data) {
	#
	# returned record doesn't contain password
	ok($meeting_params->$_ eq $parameter_str_data{$_}, "meeting parameter $_ eq $parameter_str_data{$_}");
    }

    foreach (keys %parameter_int_data) {
	ok($meeting_params->$_ == $parameter_int_data{$_}, "meeting parameter $_ == $parameter_int_data{$_}");
    }

    my %meeting_server_data = (
	boundaryMinutes => 15,
	fullPermissions => 1,
	supervised => 1,
    );

    #
    # seats are updated via the updateMeeting adapter
    #
    ok($meeting->update({seats => 2}), 'can update number of seats in the meeting');

    my $server_params = Elive::Entity::ServerParameters->retrieve([$meeting->meetingId]);

    isa_ok($server_params, 'Elive::Entity::ServerParameters', 'server_params');

    $server_params->update(\%meeting_server_data);

    foreach (keys %meeting_server_data) {
	ok($server_params->$_ == $meeting_server_data{$_}, "server parameter $_ == $meeting_server_data{$_}");
    }

    ok($server_params->seats == 2, 'server_param - expected number of seats');

    my $pl = Elive::Entity::ParticipantList->retrieve([$meeting->meetingId]);
    diag ("participants=".$pl->participants->stringify);

    my $participants = [{user => Elive->login->userId,
			 role => 1}];
    #
    # NB. It's no neccessary to insert prior to update, but since we allow it
    lives_ok(
	     sub {Elive::Entity::ParticipantList->insert
		      (
		       {meetingId => $meeting->meetingId,
			participants => $participants},
		       )
		  },
	     'update of participant list - lives');

    my $participant_list = Elive::Entity::ParticipantList->retrieve([$meeting->meetingId]);


    isa_ok($participant_list, 'Elive::Entity::ParticipantList', 'server_params');

    #
    # check that we can access our meeting by user and date range.
    #
    my $user_meetings = Elive::Entity::Meeting->list_user_meetings_by_date(
	[$meeting_str_data{facilitatorId},
	 $meeting_int_data{start},
	 $meeting_int_data{end},
	 ]
	);

    lives_ok(sub {Elive::Entity::ParticipantList->insert({meetingId => $meeting->meetingId,
					     participants => []})},
             'insert empty participant list - lives');

    lives_ok(sub {$participant_list->update({participants => []})},
	     'clearing participants - lives');

    my $p = $participant_list->participants;

    ok(@$participants == 1, 'participant_list - cleared');

    do {
	my $jnlp;
	lives_ok(sub {$jnlp = $meeting->buildJNLP(version => '8.0')},
		'$meeting->buildJNLP - lives');

	ok(defined $jnlp, 'got jnlp')
    };

    isa_ok($user_meetings, 'ARRAY', 'user_meetings');

    my $meeting_id = $meeting->meetingId;

    ok(@$user_meetings, 'found user meetings by date');
    ok ((grep {$_->meetingId == $meeting_id} @$user_meetings),
	'meeting is in user_meetings_by_date');

    #
    # start to tidy up
    #

    lives_ok(sub {$meeting->delete},'meeting deletion');
    #
    # This is an assertion of server behaviour. Just want to verify that
    # meeting deletion cascades to meeting & server parameters
    # are deleted when the meeting is deleted.
    #
    $meeting_params = undef;
    dies_ok( sub {Elive::Entity::MeetingParameters->retrieve([$meeting_id])},
	     'cascaded delete of meeting parameters');

    $server_params = undef;
    dies_ok( sub {Elive::Entity::ServerParameters->retrieve([$meeting_id])},
	     'cascaded delete of server parameters');
}

Elive->disconnect;
