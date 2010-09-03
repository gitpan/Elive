#!perl -T
use warnings; use strict;
use Test::More tests => 29;
use Test::Exception;

package main;

BEGIN {
	use_ok( 'Elive' );
	use_ok( 'Elive::Connection' );
	use_ok( 'Elive::Entity::User' );
	use_ok( 'Elive::Entity::Preload' );
	use_ok( 'Elive::Entity::Meeting' );
	use_ok( 'Elive::Entity::MeetingParameters' );
}

Elive->connection(Elive::Connection->connect('http://test.org'));

dies_ok(
    sub {
	Elive::Entity::User->construct
	    ({	loginName => 'user',
		loginPassword => 'pass'})},
##    "can't construct Elive::Entity::User without value for primary key field: userId",
    "construct without primary key - dies"
    );

my %user_data =  (
    userId => 1234,
    loginName => 'bbill',
    loginPassword => 'pass'
    );

my $user_obj;

lives_ok(
    sub {
	$user_obj = Elive::Entity::User->construct(\%user_data)
    },
    "initial construction - lives"
    );

unless ($user_obj) {
    diag "dont' have user object - unable to continue testing";
    exit(1);
}

$user_obj->loginName( $user_obj->loginName .'x' );

dies_ok(
    sub {Elive::Entity::User->construct(\%user_data)},
    "reconstructing unsaved object - dies"
    );

$user_obj->revert;

lives_ok(
    sub {Elive::Entity::User->construct(\%user_data)},
    "construction after reverting changes - lives"
    );

lives_ok(
    sub {$user_obj->set('email', 'bbill@test.org')},
    "setter on non-key value - lives"
    );

dies_ok(
    sub {$user_obj->set(userId => undef)},
    "clearing primary key field - dies"
    );

dies_ok(
    sub {$user_obj->set('userId', $user_obj->userId.'9')},
    "updating primary key field - dies"
    );

lives_ok(
    sub {$user_obj->set('userId', $user_obj->userId)},
    "ineffective primary key update - lives"
    );

my %meeting_data = (meetingId => 1111111,
		    name => 'test',
		    start => '1234567890123',
		    end => '1234567890123',
		    password => 'work!',
	);

my $meeting;

lives_ok(
    sub {$meeting = Elive::Entity::Meeting->construct(\%meeting_data)},
	 'construct meeting with valid data - lives'
    );

lives_ok(
    sub {$meeting->set(password => undef)},
    "setting optional field to undef - lives"
    );

dies_ok(
    sub {$meeting->set(start => undef)},
    "setting required field to undef - dies"
    );

$meeting->revert;

foreach (qw(meetingId name start end)) {

    my %bad_meeting_data = %meeting_data;
    delete $bad_meeting_data{$_};

    dies_ok(
	sub {Elive::Entity::Meeting->construct(\%bad_meeting_data)},
	"meeting with missing $_ - dies"
	);
}

foreach my $fld (qw/meetingId start/) {
    dies_ok(
	sub {
	    local $meeting_data{$fld} = 'non numeric data';
	    Elive::Entity::Meeting->construct(\%meeting_data);
	},
	"meeting with non numeric $fld - dies"
	);
}

lives_ok(
	 sub {Elive::Entity::MeetingParameters->construct
	     ({
		 meetingId => 1111111,
		 recordingStatus => 'remote',
	      })},
	      'meeting parameters - valid recordingStatus - lives',
    );

dies_ok(
    sub {Elive::Entity::MeetingParameters->construct
	     ({
		 meetingId => 222222,
		 recordingStatus => 'CRUD',
	      })},
	      'meeting parameters - invalid recordingStatus - dies',
    );       

lives_ok(
	 sub {Elive::Entity::Preload->construct
	     ({
		 preloadId => 333333,
		 name => 'test.swf',
		 mimeType => 'mimeType=application/x-shockwave-flash',
		 ownerId => 123456789000,
		 size => 1024,
		 type => 'media',
	      })},
	      'meeting parameters - valid type - lives',
    );       

dies_ok(
	 sub {Elive::Entity::Preload->construct
	     ({
		 preloadId => 333333,
		 name => 'test.swf',
		 mimeType => 'mimeType=application/x-shockwave-flash',
		 ownerId => 123456789000,
		 size => 1024,
		 type => 'crud',
	      })},
	      'meeting parameters - invalid type - dies',
    );

lives_ok(
    sub{Elive::Entity::MeetingParameters->_thaw
	    ({
		MeetingParametersAdapter => {
		    Id => 11111222233334444,
		    RecordingStatus => 'REMOTE',
		}})
    },
    'thawing valid meeting struct parameters - lives',
    );


dies_ok(
    sub{Elive::Entity::MeetingParameters->_thaw
	    ({
		CrudAdapter => {
		    Id => 11111222233334444,
		    RecordingStatus => 'REMOTE',
		}})
    },
    'thawing invalid meeting struct parameters - dies',
    );

$user_obj->revert;
Elive->disconnect;
