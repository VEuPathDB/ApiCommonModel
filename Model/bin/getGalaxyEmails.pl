#!/usr/bin/perl

use strict;

use DBI;
use DBD::Oracle;
use Getopt::Long;
use CBIL::Util::V;
use Data::Dumper;

my ($help, $inFile,$outFile);

&GetOptions('help|h' => \$help,
            'inputFile=s' => \$inFile,
            'outputFile=s' => \$outFile,
            );

&usage() if ($help || ! $inFile || ! $outFile);

my $database = "acctdbn";

my $dbh = &connectToDb($database);
my ($userIds,$nonVeupathEmails) = &readInputFile($inFile);
my $idsToEmails = &lookUpIdsEmails($dbh);
my $veupathEmails = &convertIdsToEmails($userIds,$idsToEmails);
&writeOutputFile($outFile,$nonVeupathEmails,$veupathEmails);
$dbh->disconnect();

exit;


sub readInputFile {
    my ($inFile) = @_;
    my (%userIds, %nonVeupathEmails);
    open(my $fh,$inFile) || die "Count not open $inFile for reading\n";
    while (my $line = <$fh>) {
	if ($line =~ /(\S+\@\S+)/) {                   # an email address
	    my $email = $1;
	    if ($email =~ /\.(\d+)\@veupathdb\.org/) { # veupath account
		$userIds{$1} = 1;
	    } else {                                  # non veupath email
		$nonVeupathEmails{$email} = 1;
	    }
	}
    }
    close $fh;
    return (\%userIds,\%nonVeupathEmails);
}

sub lookUpIdsEmails {
    my ($dbh) = @_;
    my %idsToEmails;
    my $sql = "SELECT user_id, email FROM useraccounts.accounts";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    while (my ($id,$email) = $sh->fetchrow_array()) {
	$idsToEmails{$id} = $email;
    }
    return \%idsToEmails;
}

sub convertIdsToEmails {
    my ($userIds,$idsToEmails) = @_;
    my %veupathEmails;
    foreach my $id (keys %{$userIds}) {
	if (! exists $idsToEmails->{$id}) {
	    print "This user id cannot be found in the database: $id\n";
	} else {
	    $veupathEmails{$idsToEmails->{$id}} = 1;
	}
    }
    return \%veupathEmails;
}

sub writeOutputFile {
    my ($outFile,$nonVeupathEmails,$veupathEmails) = @_;
    open(my $fh,">",$outFile) || die "Cannot open file $outFile for writing\n";
    print $fh join(",", (keys %{$veupathEmails}, keys %{$nonVeupathEmails}))."\n";
    close $fh;
}

sub usage {
    die "
getGalaxyEmails --help/-h --inputFile <file-with-galaxy-accounts> --outputFile <file-name>

Required Environment Variables: DBI_USER DBI_DSN DBI_PASS

This script takes a file with one Globus/Navipoint/Galaxy user id per line. Other fields can be on the line.

User ids are in the form of markhic.123456789\@veupathdb.org or human\@gmail.com. The veupath ids are used with the 
database to retrieve the email address. All email addresses are placed into one line of the output file delimited by a comma
"
}

# use DBI's standard env vars to get credentials
sub connectToDb {
  my ($instance) = @_;
  my $dbiDsn = 'dbi:Oracle:' . $instance;
  my $dbh = DBI->connect($dbiDsn) or die DBI->errstr;
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 0;
  return $dbh;
}

1;
