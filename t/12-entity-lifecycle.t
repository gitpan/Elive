#!perl -T
use warnings; use strict;
use Test::More tests => 8;
use Test::Warn;

package main;

my $meta_data_tab = \%Elive::Meta_Data;

BEGIN {
    use_ok( 'Elive' );
    use_ok( 'Elive::Connection' );
    use_ok( 'Elive::Entity' );
    use_ok( 'Elive::Entity::User' );
};

use Scalar::Util;

my $URL1 = 'http://test1.org';

my $K1 = 123456123456;
my $K2 = 112233445566;
my $K3 = 111222333444;
my $C1 = Elive::Connection->connect($URL1);

Elive->connection($C1);

my $user =  Elive::Entity::User->construct(
    {userId => $K1,
     loginName => 'pete'},
    );

my $url = $user->url;
#
# we need to trick the perl interpreter into not treating this as a reference
#
my $refaddr = sprintf("%s",$user->_refaddr) . '';
my $is_live = defined(Elive::Entity->live_entity($url));
ok($is_live, 'entity is live');

ok(defined($meta_data_tab->{$refaddr}), 'entity has metadata');

#
# right, lets get rid of the object
#
$user = undef;

my $is_dead = !(Elive::Entity->live_entity($url));
ok($is_dead, 'entity is dead');
ok(!$meta_data_tab->{$refaddr}, 'entity metadata destroyed');
