#!perl -T
use strict;
use warnings;
use Test::More;

diag( "Testing Elive $Elive::VERSION, Perl $], $^X" );

my $MODULE = 'Test::Strict';
eval "use $MODULE";
plan skip_all => "$MODULE not available for strict tests" if $@;

all_perl_files_ok( 'lib', 'script' );
