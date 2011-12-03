#!perl -T
use warnings; use strict;
use Test::More tests => 7;
use Test::Fatal;

use lib '.';
use t::Elive;

use Elive;
use Elive::Entity::Meeting;

my $class = 'Elive::Entity::Meeting' ;

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 7)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my %meeting_data = (
	name => 'test meeting, generated by t/soap-meeting-recurring.t',
	password => 'test', # what else?
	facilitatorId => Elive->login,
	start => time() .'000',
	end => (time()+900) . '000',
	recurrenceCount => 3,
	recurrenceDays => 7,
	
    );

    my @meetings;
    is ( exception {@meetings = $class->insert(\%meeting_data)} => undef, 'creation of recurring meeting - lives');

    ok(@meetings == 3, 'got three meeting occurrences')
	or die "meeting is not recurring - aborting";

    my $n;
    foreach (@meetings) {
	isa_ok($_, $class, "meeting occurence ".++$n);
    }

    my @start_times = map {substr($_->end, 0, -3)} @meetings;

    #
    # very approximate test on the dates being about a week apart. Allow
    # times could be out by over 1.5 hours due to daylight savings etc. 

    ok(t::Elive::a_week_between($start_times[0], $start_times[1]),
		       "meetings 1 & 2 separated by one week (approx)");

    ok(t::Elive::a_week_between($start_times[1], $start_times[2]),
       "meetings 2 & 3 separated by one week (approx)");

    foreach (@meetings) {
	$_->delete;
    }
}

Elive->disconnect;
