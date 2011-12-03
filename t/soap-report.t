#!perl -T
use warnings; use strict;
use Test::More tests => 14;
use Test::Fatal;
use Test::Builder;

use lib '.';
use t::Elive;

use Elive;

use XML::Simple;

my $t = Test::Builder->new;

my $class = 'Elive::Entity::Report';
use Elive::Entity::Report;

SKIP: {

    my %result = t::Elive->test_connection(only => 'real');
    my $auth = $result{auth};

    skip ($result{reason} || 'skipping live tests', 14)
	unless $auth;

    my $connection_class = $result{class};
    my $connection = $connection_class->connect(@$auth);
    Elive->connection($connection);

    my $reports;

    is( exception {$reports = Elive::Entity::Report->list} => undef, 'reports list method - lives');

   isa_ok($reports, 'ARRAY', 'reports list results');

    unless (@$reports) {
	#
	# a bit unexpected, because Elluminate comes with built in reports
	#
        diag("** Hmmm, No reports on this server - skipping further report tests !!!?");
	Elive->disconnect;

        skip('No reports found!?', 12);
    };

   isa_ok($reports->[0], 'Elive::Entity::Report', 'reports[0]');

   #
   # note that the list method (listReports command) does not return the
   # list body. We need to refetch
   my $report_id;

   ok($report_id = $reports->[0]->reportId, 'reports[0] has reportId');

   my $rpt;
   is ( exception {$rpt = Elive::Entity::Report->retrieve($report_id)} => undef,
                 'retrieve reports[0].id - lives');

    my $sample_xml = $rpt->xml;

    ok($sample_xml, 'reports[0].xml - populated');
    is( exception {XMLin($sample_xml)} => undef, 'reports[0].xml is valid XML');

    if ( $ENV{ELIVE_TEST_REPORT_UPDATES} ) {
	#
	# do some live create/update/delete tests on reports
	#
	my $gen_id = t::Elive::generate_id();
	my $trivial_xml = join('', <DATA>);

	is( exception {XMLin( $trivial_xml)} => undef, 'XML sanity' );

	my %report_data = (
	    name => "empty report generated by soap-report.t ($gen_id)",
	    description => 'temporary empty report, created by soap-report.t (Elive test suite, with live testing of report updates enabled)',
	    xml => $trivial_xml,
	    );

	my $report;

	is( exception {$report = Elive::Entity::Report->insert(\%report_data)} => undef,
		 'trivial insert - lives');

	foreach (sort keys %report_data) {

	    if ($_ eq 'xml') {
		# buildargs does some stripping
		like($report->$_, qr{<jasperReport}, "inserted $_");
	    }
	    else {
		is($report->$_, $report_data{$_}, "inserted $_");
	    }
	}

      TODO: {
	  #
	  # Insert/update of full-length XML reports gives variable
	  # results. Tested on various ELM 3.0 - 3.3.5
	  #
	  # Also to-do; further work on the readback. Reponse
	  # XML may not exactly match the input XML.
	  #
	   local($TODO) = 'report content insert/update';

	   is( exception {$report->update({xml => $sample_xml})} => undef,
		    'copy of live report - lives');
	};

	is( exception {$report->delete} => undef, 'report deletion - lives');
    }
    else {
	$t->skip('skipping live report update tests')
	    for (1..7);
    }

    Elive->disconnect;

}

# just try a trivial Jasper report.
__DATA__
<jasperReport name="EliveEmptyTestReportPleaseDelete"></jasperReport>
