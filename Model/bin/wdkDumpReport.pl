#!/usr/bin/perl
use strict;

use DBI;
use DBD::Oracle;

use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;



my ($dbPrefixes, $liveSuffix, $login, $outputFile, $password);
&GetOptions("dbPrefixes=s" => \$dbPrefixes,
            "liveSuffix=s" => \$liveSuffix,
            "login=s" => \$login,
            "outputFile=s" => \$outputFile,
            "password=s" => \$password);

#####dbPrefixes should be comma delimted with no spaces, e.g."plas,giar"
#####liveSuffix e.g. "045"

if (!$dbPrefixes || !$liveSuffix || !$login || !$password || !$outputFile) {
die "wdkDumpReport.pl --dbPrefixes --liveSuffix --login --password --ou
tputFile\n";}

open(FILE, ">>$outputFile");

my @prefixes = split(/\,/,$dbPrefixes);

my %report;

my $geneSql = "select count(*) from apidb.genedetail";
my $isolateSql = "select count(*) from apidb.isolatedetail";
my $compoundSql = "select count(*) from apidb.compounddetail";
my $fieldSql = "select count(distinct field_name) from apidb.genedetail";

foreach my $prefix (@prefixes) {
        my $incInstance = $prefix . "-inc";
	my $dbDbh = DBI->connect("dbi:Oracle:$incInstance",$login,$password) or die DBI->errstr;
        $dbDbh->{RaiseError} = 1;
        $dbDbh->{AutoCommit} = 0;
	my $geneCountInc = $dbDbh->selectrow_array ($geneSql);
        my $isolateCountInc = $dbDbh->selectrow_array ($isolateSql);
	my $compoundCountInc = $dbDbh->selectrow_array ($compoundSql);
	my $fieldCountInc = $dbDbh->selectrow_array ($fieldSql);
        $dbDbh->disconnect();

        my $liveInstance = "$prefix$liveSuffix" ;       
        $dbDbh = DBI->connect("dbi:Oracle:$liveInstance",$login,$password) or die DBI->errstr;
        $dbDbh->{RaiseError} = 1;
        $dbDbh->{AutoCommit} = 0;
        my $geneCountLive = $dbDbh->selectrow_array ($geneSql);
        my $isolateCountLive = $dbDbh->selectrow_array ($isolateSql);
        my $compoundCountLive = $dbDbh->selectrow_array ($compoundSql);
        my $fieldCountLive = $dbDbh->selectrow_array ($fieldSql);
        $dbDbh->disconnect();
 
	print FILE "$prefix-inc - $prefix$liveSuffix\ngeneDetail: $geneCountInc - $geneCountLive\nisolateDetail: $isolateCountInc - $isolateCountLive\ncompoundDetail: $compoundCountInc - $compoundCountLive\nfieldName count: $fieldCountInc - $fieldCountLive\n\n";
}
