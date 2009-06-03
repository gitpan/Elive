#!perl -T
use warnings; use strict;
use Test::More tests => 48;
use Test::Warn;

BEGIN {
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity::User' );
    use_ok( 'Elive::Entity::ParticipantList' );
    use_ok( 'Elive::Util');
};

ok(Elive::Util::_thaw('123456', 'Int') == 123456, 'simple Int');
ok(Elive::Util::_thaw('+123456', 'Int') == 123456, 'Int with plus sign');
ok(Elive::Util::_thaw('00123456', 'Int') == 123456, 'Int with leading zeros');
ok(Elive::Util::_thaw('-123456', 'Int') == -123456, 'Int negative');
ok(Elive::Util::_thaw('-00123456', 'Int') == -123456, 'Int negative, leading zeros');
ok(Elive::Util::_thaw('+00123456', 'Int') == 123456, 'Int plus sign leading zeros');
ok(Elive::Util::_thaw('01234567890000', 'HiResDate') eq '1234567890000', 'date, leading zero');
ok(Elive::Util::_thaw(0, 'Int') == 0, 'Int zero');
ok(Elive::Util::_thaw('-0', 'Int') == 0, 'Int minus zero');
ok(Elive::Util::_thaw('+0', 'Int') == 0, 'Int plus zero');
ok(Elive::Util::_thaw('0000', 'Int') == 0, 'Int multiple zeros');

ok(!Elive::Util::_thaw('false', 'Bool'), 'Bool false => 0');
ok(Elive::Util::_thaw('true', 'Bool'), 'Bool true => true');

ok(Elive::Util::_thaw('  abc ', 'Str') eq 'abc', 'String l-r trimmed');

Elive->connection(Elive::Connection->connect('http://test.org'));

my $user_data = {
    UserAdapter
	=> {
	    Id            => 1239260932,
	    Deleted       => 'false',
	    Email         =>  'bbill@test.com',
	    FirstName     => 'Blinky',
	    LastName      => 'Bill',
	    LoginName     => 'blinkybill',
	    LoginPassword => '',
            Role          => {
		RoleAdapter => {
		    RoleId => 3,
		},
	    },
    },
};

my $user_thawed = Elive::Entity::User->_thaw($user_data);

is_deeply($user_thawed,
	  {
	      email => 'bbill@test.com',
	      firstName => 'Blinky',
	      loginPassword => '',
	      loginName => 'blinkybill',
	      userId => '1239260932',
	      deleted => 0,
	      lastName => 'Bill',
	      role => {
		  roleId => '3'
	      }
	  },
	  'user thawed',
    );

my $user_object = Elive::Entity::User->construct($user_thawed);

isa_ok($user_object, 'Elive::Entity::User', 'constructed object');
isa_ok($user_object->role, 'Elive::Entity::Role', 'constructed object role');

my %user_contents = map {$_ => $user_object->$_} ($user_object->properties);

#
# Round trip verification. We can reconstruct the object from data
#
is_deeply(\%user_contents,
	  {
	      email => 'bbill@test.com',
	      firstName => 'Blinky',
	      loginPassword => '',
	      loginName => 'blinkybill',
	      userId => '1239260932',
	      deleted => 0,
	      lastName => 'Bill',
	      role => bless (
		  {
		      roleId => '3',
		  }, 'Elive::Entity::Role')
	  },
	  'constructed object contents',
    );

{
    #
    # try toogling a boolean flag, while we're at it
    #
    local $user_data->{UserAdapter}{Deleted} = 'true';
    my $user2_thawed = Elive::Entity::User->_thaw($user_data);

    ok($user2_thawed->{deleted}, 'thawing of set boolean flag');
}

#
# Do entire process: unpacking, thawing, consrtucting
#
my $participant_data = {
    'ParticipantListAdapter' => {
	'MeetingId' => '1239850348031',
	'Participants' => {
	    'Map' => {
		'Entry' => [
		    {
			'Value' => {
			    'ParticipantAdapter' => {
				'Role' => {
				    'RoleAdapter' => {
					'RoleId' => '3'
				    }
				},
				'User' => {
				    'UserAdapter' => {
					'FirstName' => 'David',
					'Role' => {
					    'RoleAdapter' => {
						'RoleId' => '2'
					    }
					},
					'Id' => '1239261045',
					'LoginPassword' => '',
					'LastName' => 'Warring',
					'Deleted' => 'false',
					'Email' => 'david.warring@gmail.com',
					'LoginName' => 'davey_wavey'
				    }
				}
			    }
			},
			'Key' => '1239261045'
		    },
		    {
			'Value' => {
			    'ParticipantAdapter' => {
				'Role' => {
				    'RoleAdapter' => {
					'RoleId' => '3'
				    }
				},
				'User' => {
				    'UserAdapter' => {
					'FirstName' => 'Blinky',
					'Role' => {
					    'RoleAdapter' => {
						'RoleId' => '2'
					    }
					},
					'Id' => '1239260932',
					'LoginPassword' => '',
					'LastName' => 'Bill',
					'Deleted' => 'false',
					'Email' => 'bbill@test.org',
					'LoginName' => 'blinkybill'
				    }
				}
			    }
			},
			'Key' => '1239260932'
		    }
		    ]
	    }
	},
    }
};

my $participant_list_sorbet  = Elive::Entity::ParticipantList->_unpack_results($participant_data);

#
# just some spot checks dereferencing. Tidied up somewhat, but still pretty
# verbose!
#
{
    my $p = $participant_list_sorbet;
    ok($p = $p->{$_}, "found $_ in data")
	foreach(qw{ParticipantListAdapter Participants});

    isa_ok($p, 'ARRAY', 'ParticipantListAdapter->Participants');
    ok($p = $p->[1], 'found ParticipantListAdapter->Participant->[1]');

    foreach (qw{ParticipantAdapter User UserAdapter Role RoleAdapter RoleId}) {
	ok($p = $p->{$_}, "hash deref $_");
    }

    ok($p == $_, "sorbet 2nd participants role is $_") for (2);
}

my $participant_list_thawed = Elive::Entity::ParticipantList->_thaw($participant_list_sorbet);

#
# Run the equivalent checks on the thawed file
#
{
    my $p = $participant_list_thawed;
    ok($p = $p->{$_}, "found $_ in data") for('participants');

    isa_ok($p, 'ARRAY', 'participants');
    ok($p = $p->[1], 'found participants->[1]');

    foreach (qw{user role roleId}) {
	ok($p = $p->{$_}, "hash deref $_");
    }

    ok($p == $_, "thawed 2nd participants role is $_") for (2);
}

#
# Now construct and retest
#

my $participant_list_obj =  Elive::Entity::ParticipantList->construct($participant_list_thawed);


{
    my $p = $participant_list_obj;
    ok($p = $p->$_, "found $_ in data") for('participants');

    isa_ok($p, 'Elive::Array', 'participants');
    ok($p = $p->[1], 'found participants->[1]');

    foreach (qw{user role roleId}) {
	ok($p = $p->$_, "method deref $_");
    }

    ok($p == $_, "thawed 2nd participants role is $_") for (2);
}




