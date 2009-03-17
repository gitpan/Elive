package Elive::Util;
use warnings; use strict;

use Term::ReadKey;
use Term::ReadLine;
use Scalar::Util;
use Storable;

=head1 NAME

Elive::Util - utility functions for Elive

=cut

=head2 parse_type

   my $user_types = Elive::Entity::User->property_types

   my ($type,
       $is_array,
       $is_entity,
       $is_pkey) = Elive::Util::parse_type($user_types->{role})

   if ($is_entity) {
       my $sub_types = $type->property_types
       ...
    }

Analyses an entity property type.

=cut

sub parse_type {
    my $type = shift;

    my $is_array = ($type =~ s{^ArrayRef\[(.*?)\]$}{$1});
    #
    # Note: Elive::Entity is a subclass of Elive::Struct
    #
    my $is_entity = UNIVERSAL::isa($type, 'Elive::Struct')
	||  UNIVERSAL::isa($type, 'Elive::Array');

    my $is_pkey = ($type =~ s{^pkey}{}i);

    $type = 'Int' if ($is_pkey && $type eq '');

    return ($type, $is_array, $is_entity, $is_pkey);
}

=head2 prompt

    my $password = Elive::Util::prompt('Password: ', password =>1)

Prompt for user input

=cut

sub prompt {

    chomp(my $prompt = shift || 'input:');
    my %opt = @_;

    ReadMode $opt{password}? 2: 1; # Turn off controls keys

    my $input;
    my $n = 0;

    do {
	die "giving up on input of $prompt" if ++$n > 100;
	print $prompt if -t STDIN;
	$input = ReadLine(0);
	return undef unless (defined $input);
	chomp($input);
    } until (defined($input) && length($input));

    ReadMode 0; # Reset tty mode before exiting

    return $input;
}

sub _reftype {
    return Scalar::Util::reftype( shift() ) || '';
}

sub _clone {
    return Storable::dclone(shift);
}

1;
