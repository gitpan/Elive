#!perl -T

use Test::More tests => 11;

BEGIN {
	use_ok( 'Elive' );
	use_ok( 'Elive::Connection' );
	use_ok( 'Elive::Entity' );
	use_ok( 'Elive::Entity::Group' );
	use_ok( 'Elive::Entity::Meeting' );
	use_ok( 'Elive::Entity::MeetingParameters' );
	use_ok( 'Elive::Entity::Participant' );
	use_ok( 'Elive::Entity::ParticipantList' );
	use_ok( 'Elive::Entity::Role' );
	use_ok( 'Elive::Entity::ServerDetails' );
	use_ok( 'Elive::Entity::User' );
}

diag( "Testing Elive $Elive::VERSION, Perl $], $^X" );
