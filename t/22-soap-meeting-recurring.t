#!perl
use warnings; use strict;
use Test::More tests => 6;
use Test::Exception;

package main;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::Meeting' );
};

my $class = 'Elive::Entity::Meeting' ;

SKIP: {

    my %result = Elive->_get_test_auth();
    my $auth = $result{auth};

    skip ($result{reason} || 'unable to find test connection',
	4)
	unless $auth;

    Elive->connect(@$auth);

    my %meeting_str_data = (
	name => 'test meeting, generated by t/21-soap-meeting.t',
	password => 'test', # what else?
    );

    my %meeting_int_data = (
	facilitatorId => Elive->login->userId,
	start => time() * 1000,
	end => (time()+900) * 1000,
	recurrenceCount => 3,
	recurrenceDays => 7,
	
    );

    my @meetings = ($class->insert({%meeting_int_data, %meeting_str_data}));

    ok(@meetings == 3, 'got three meeting occurences');

    foreach (@meetings) {
	isa_ok($_, $class, "meeting occurence");
    }

    foreach (@meetings) {
	$_->delete;
    }
}

Elive->disconnect;
