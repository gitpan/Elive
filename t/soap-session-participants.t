#!perl -T
use warnings; use strict;
use Test::More tests => 29;
use Test::Exception;
use Test::Builder;

use lib '.';
use t::Elive;

use Carp; $SIG{__DIE__} = \&Carp::confess;
use version;

use Elive;
use Elive::Entity::ParticipantList;
use Elive::Entity::Session;
use Elive::Entity::User;
use Elive::Entity::Group;
use Elive::Util;

our $t = Test::Builder->new;
our $class = 'Elive::Entity::Session' ;

our $connection;

SKIP: {

    my %result = t::Elive->test_connection( only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 29)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);
    #
    # ELM 3.3.4 / 10.0.2 includes significant bug fixes
    our $elm_3_3_4_or_better =  (version->declare( $connection->server_details->version )->numify
				 > version->declare( '10.0.1' )->numify);

    my $session_start = time();
    my $session_end = $session_start + 900;

    $session_start .= '000';
    $session_end .= '000';

    my $participants_deep_ref = [{user => Elive->login->userId,
				  role => 2}];

    is_deeply($class->_freeze({participants => $participants_deep_ref}),
	      {invitedGuests => '',
	       invitedModerators =>  Elive->login->userId,
	       invitedParticipantsList => '',
	      }, 'freeze single participating user');

    my %session_data = (
	name => 'test session, generated by t/soap-session-participants.t',
	facilitatorId => Elive->login->userId,
	password => 'test', # what else?
	start =>  $session_start,
	end => $session_end,
	privateMeeting => 1,
	participants => $participants_deep_ref,
    );

    my ($session) = $class->insert(\%session_data);

    isa_ok($session, $class, 'session');

    my $participant_list = $session->participantList;

    isa_ok($participant_list, 'Elive::Entity::ParticipantList', '$session->participants');
    is($participant_list->participants->stringify, Elive->login->userId.'=2',
       'insert of single user participant');
    #
    # lets grab some volunteers from the audience!
    #
    my ($participant1, $participant2, @participants);

    lives_ok( sub {
	#
	# for datasets with 1000s of entries
	($participant1, $participant2, @participants) = grep {$_->userId ne $session->facilitatorId} @{ Elive::Entity::User->list(filter => 'lastName = Sm*') };
	#
	# for modest test datasets
	($participant1, $participant2, @participants) = grep {$_->userId ne $session->facilitatorId} @{ Elive::Entity::User->list() }
	    unless @participants;
	      },
	      'get_users - lives');

    #
    # only want a handful
    #
    splice(@participants, 10)
	if (@participants > 10);

    if (@participants) {

	$session->participants->add($participant1->userId.'=3');

	lives_ok(sub {$session->update}, 'setting of participant - lives');
	if ($elm_3_3_4_or_better) {
	    ok($session->is_participant( $participant1), 'is_participant($participant1)');
	}
	else {
	    $t->skip('is_participant() - broken prior to ELM 3.3.4 / 10.0.2');
	}

	ok(!$session->is_moderator( $participant1), '!is_moderator($participant1)');

	ok((grep {$_->user->userId eq $participant1->userId} @{ $session->participants }), 'participant 1 found in participant list');
	ok((grep {$_->user->userId eq $participant1->userId && $_->role->roleId == 3} @{ $session->participants }), 'participant 1 is not a moderator');

	$session->participants->add($participant2->userId.'=3');
	$session->update();

	if ($elm_3_3_4_or_better) {
	    ok($session->is_participant( $participant2), 'is_participant($participant2)');
	}   
        else {  
            $t->skip('is_participant() - broken prior to ELM 3.3.4 / 10.0.2');
        }

 	ok(!$session->is_moderator( $participant2), '!is_moderator($participant2)');

	ok((grep {$_->user->userId eq $participant2->userId} @{ $session->participants }), 'participant 2 found in participant list');
	ok((grep {$_->user->userId eq $participant2->userId && $_->role->roleId == 3} @{ $session->participants }), 'participant 2 is not a moderator');

    }
    else {
	$t->skip('unable to find any other users to act as participants(?)',)
	    for (1..9);
    }

    $session->revert();

    if (@participants) {
	lives_ok( sub {$session->update({participants => \@participants}),
		  }, 'setting up a larger session - lives');
    }
    else {
	$t->skip('insufficient users to run large session tests');
    }

    ok($session->is_participant( Elive->login), 'is_participant($moderator)');
    ok($session->is_moderator( Elive->login), 'is_moderator($moderator)');

    my $gate_crasher = 'gate_crasher_'.t::Elive::generate_id();

    ok(!$session->is_participant( $gate_crasher ), '!is_participant($gate_crasher)');
    ok(!$session->is_moderator( $gate_crasher ), '!is_moderator($gate_crasher)');

    dies_ok(sub {
	$session->participants->add($gate_crasher.'=3');
	$session->update($gate_crasher.'=3');
	    },
	    'add of unknown participant - dies');

    lives_ok(sub {$session->update({participants => []})},
	     'clearing participants - lives');

    my $p = $session->participants;

    #
    # check our reset policy. Updating/creating an empty participant
    # list is effectively the same as a reset. Ie, we end up with
    # the facilitator as the sole participant, with a role of moderator (2).
    #

    is(@$p, 1, 'participant_list reset - single participant');

    is($p->[0]->user && $p->[0]->user->userId, $session->facilitatorId,
       'participant_list reset - single participant is the facilitator');

    is($p->[0]->role && $p->[0]->role->roleId, 2,
       'participant_list reset - single participant has moderator role');

    if ( !$participant2 )  {
	$t->skip('not enough participants to run long-list test');
    }
    else { 
	#
	# stress test underlying setParticipantList command we need to do a direct SOAP
	# call to bypass overly helpful readback checks and removal of duplicates.
	#
	my @big_user_list;

      MAKE_BIG_LIST:
	while (1) {
	    foreach ($participant1, $participant2, @participants) {
		#
		# include a smattering of unknown users
		#
		my $user = rand() < .1 ? t::Elive::generate_id(): $_->userId;
		push (@big_user_list, $user);
		last MAKE_BIG_LIST
		    if @big_user_list > 2500;
	    }
	}

	dies_ok( sub {
	  $session->update( {participants => [
				-moderators => Elive->login,
				-others => @big_user_list
				 ] } )
		  }, 'session participants long-list - dies'
	      );

	$session->revert;
	#
	# refetch the participant list and check that all real users
	# are present
	#
	my @users_in =  (Elive->login, $participant1, $participant2, @participants);
	my @user_ids_in = map {$_->userId} @users_in;
	my %users_seen;
	@users_seen{ @user_ids_in } = undef;
	my @expected_users = sort keys %users_seen;
	#
	# retrieve via elm 2x getParticipantList command
	#
	$participant_list = Elive::Entity::ParticipantList->retrieve($session->id, copy => 1);
	my $participants = $participant_list->participants;

	my @actual_users = sort map {$_->user->userId} @$participants;

	is_deeply(\@actual_users, \@expected_users, "participant list as expected (no repeats or unknown users)");
    }

    my $group;
    my @groups;
    my $group_member;
    #
    # test groups of participants
    #
    lives_ok( sub {
	@groups = @{ Elive::Entity::Group->list() } },
	'list all groups - lives');

    splice(@groups, 10) if @groups > 10;

    #
    # you've got to refetch the group to populate the list of recipients
    ($group) = grep {$_->retrieve($_); @{ $_->members } } @groups;

    if ($group) {
	my $invited_guest = 'Robert(bob)';
	diag "using group ".$group->name;
	lives_ok(sub {$session->update({ participants => [$group, $participant1, $invited_guest]})}, 'setting of participant groups - lives');
    }
    else {
	$t->skip('no candidates found for group tests');
    }

    #
    # tidy up
    #

    lives_ok(sub {$session->delete},'session deletion');
}

Elive->disconnect;

