package Elive::Entity;
use warnings; use strict;
use Mouse;
use Mouse::Util::TypeConstraints;

extends 'Elive::DAO';

=head1 NAME

    Elive::Entity - Base class for Elive Entities

=head1 DESCRIPTION

This is the base class for bindings to the command adapter, the default
Elluminate live API.

=cut

=head2 data_classes

returns a list of all entity classes

=cut

sub data_classes {
    my $class = shift;
    return qw(
      Elive::Entity::Group
      Elive::Entity::MeetingParameters
      Elive::Entity::Meeting
      Elive::Entity::ParticipantList
      Elive::Entity::Preload
      Elive::Entity::Recording
      Elive::Entity::Report
      Elive::Entity::ServerDetails
      Elive::Entity::ServerParameters
      Elive::View::Session
      Elive::Entity::User
   );
}

#
# Normalise our data and reconstruct arrays.
#
# See t/05-entity-unpack.t for examples and further explanation.
#

sub _get_results {
    my $class = shift;
    my $som = shift;
    my $connection = shift;

    $connection->_check_for_errors($som);

    my $results_list = $class->_unpack_as_list($som->result);

    return $results_list;
}

sub _unpack_as_list {
    my $class = shift;
    my $result = shift;

    $result = $class->_unpack_results($result);

    my $reftype = Elive::Util::_reftype($result);

    my $results_list;

    if ($reftype eq 'HASH') {

	$results_list = [ $result ];

    }
    elsif ($reftype eq 'ARRAY') {

	$results_list = $result;

    }
    elsif ($reftype) {
	Carp::croak "unknown type in result set: $reftype";
    }
    else {

	$results_list = defined($result) && $result ne ''
	    ? [ $result ]
	    : [];

    }

    warn "$class result: ".YAML::Dump($result)
	if ($class->debug >= 2);

    return $results_list;
}

sub _unpack_results {
    my $class = shift;
    my $results = shift;

    my $results_type = Elive::Util::_reftype($results);

    if (!$results_type) {
	return $results;
    }
    elsif ($results_type eq 'ARRAY') {
	return [map {$class->_unpack_results($_)} @$results];
    }
    elsif ($results_type eq 'HASH') {
	#
	# Convert some SOAP/XML constructs to their perl equivalents
	#
	foreach my $key (keys %$results) {
	    my $value = $results->{$key};

	    if ($key eq 'Collection') {

		if (Elive::Util::_reftype($value) eq 'HASH'
		    && exists ($value->{Entry})) {
		    $value = $value->{Entry};
		}
		else {
		    $value = [];
		}
		#
		# Throw away our parse of this struct. It only exists to
		# house this collection
		#
		return $class->_unpack_results($value);
	    }
	    elsif ($key eq 'Map') {

		if (Elive::Util::_reftype($value) eq 'HASH') {

		    if (exists ($value->{Entry})) {

			$value = $value->{Entry};
			#
			# Looks like we've got Key, Value pairs.
			# Throw array the key and reference the value,
			# that's all we're interested in.
			#
			if (Elive::Util::_reftype ($value) eq 'ARRAY') {
		    
			    $value = [map {$_->{Value}} @$value];
			}
			else {
			    $value = $value->{Value};
			}
		    }
		}
		else {
		    $value = [];
		}
		#
		# Throw away our parse of this struct it only exists to
		# house this collection
		#
		return $class->_unpack_results($value);
	    }

	    $results->{$key} = $class->_unpack_results($value);
	}
	    
    }
    else {
	die "Unhandled type in response body: $results_type";
    }

    return $results;
}

=head1 SEE ALSO

 Elive::DAO
 Elive::Struct
 Mouse

=cut

1;
