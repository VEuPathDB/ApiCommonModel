#!/usr/bin/perl

use strict;
use DBI;
use DBD::Oracle;
use Getopt::Long;
use CBIL::Util::V;
use CBIL::Util::Utils;
use CBIL::Util::PropertySet;
use Data::Dumper;
use JSON;
use Time::HiRes;

my ($help, $databaseInstance, $taxonIds, $pattern, $outputFile);

&GetOptions('help|h' => \$help,
            'database_instance=s' => \$databaseInstance,
            'taxon_ids=s' => \$taxonIds,
            'phyletic_pattern=s' => \$pattern,
            'output_file=s' => \$outputFile,
            );

my $dbh = &connectToDb($databaseInstance);

print "Getting groups from OrthoMCL: ";
my $startTime = Time::HiRes::time();
my $groups = &getGroupsFromOrthomcl($pattern);
my $endTime = Time::HiRes::time(); 
printf("%.2f",($endTime - $startTime));
print " seconds\n";

print "Getting source ids and groups from $databaseInstance: ";
$startTime = Time::HiRes::time();
my $groupsToSourceIds = &getSourceIdsAndGroups($taxonIds,$dbh); 
$endTime = Time::HiRes::time(); 
printf("%.2f",($endTime - $startTime));
print " seconds\n";

print "Converting groups to source ids: ";
$startTime = Time::HiRes::time();
my $sourceIds = &convertGroupsToSourceIds($groups,$groupsToSourceIds);
$endTime = Time::HiRes::time(); 
printf("%.2f",($endTime - $startTime));
print " seconds\n";

my $tableName = "PhyleticPattern".time();
print "Creating and populating table '$tableName': ";
$startTime = Time::HiRes::time();
&createTable($tableName,$sourceIds,$dbh);
$endTime = Time::HiRes::time(); 
printf("%.2f",($endTime - $startTime));
print " seconds\n";

print "Final search query written to file '$outputFile': ";
$startTime = Time::HiRes::time();
&finalSearchQuery($tableName,$outputFile,$dbh);
$endTime = Time::HiRes::time(); 
printf("%.2f",($endTime - $startTime));
print " seconds\n";

print "Dropping table and database connection: ";
$startTime = Time::HiRes::time();
&dropTableAndDisconnect($tableName,$dbh);
$endTime = Time::HiRes::time(); 
printf("%.2f",($endTime - $startTime));
print " seconds\n\n";


sub dropTableAndDisconnect {
    my ($tableName,$dbh) = @_;
    my $sql = "DROP TABLE $tableName";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    $dbh->disconnect();
}

sub getGroupsFromOrthomcl {
    my ($pattern) = @_;
#    print "$pattern\n";
    $pattern = &cleanUrl($pattern);
#    print "$pattern\n";
    my $url = "https://w2.orthomcl.org/orthomcl/service/record-types/group/searches/GroupsByPhyleticPattern/reports/standard?";
    $url .= "phyletic_expression=".$pattern;
    $url .= "&reportConfig={\"attributes\":[\"primary_key\"],\"tables\":[]}";
    my $cmd = "curl --max-time 600 --silent --show-error -g '$url'";
    my $json = eval {&runCmd($cmd)};
    my $results = eval {decode_json($json)};
    my %groups;
    foreach my $groupRecord (@{$results->{records}}) {
	$groups{$groupRecord->{attributes}->{primary_key}} = 1;
    }
    my $numGroups = keys %groups;
    print "$numGroups groups, ";
    return \%groups;
}

sub cleanUrl {
    my ($url) = @_;
    $url =~ s/=/%3D/g;
    $url =~ s/>/%3E/g;
    $url =~ s/</%3C/g;
    $url =~ s/ /%20/g;
    $url =~ s/\./%2E/g;
    $url =~ s/-/%2D/g;
    $url =~ s/:/%3A/g;
    $url =~ s/,/%2C/g;
    $url =~ s/\//%2F/g;
    $url =~ s/\(/%28/g;
    $url =~ s/\)/%29/g;
    return $url;
}

sub getSourceIdsAndGroups {
    my ($taxonIds,$dbh) = @_;
    my $sql = "SELECT source_id, orthomcl_name
               FROM webready.TranscriptAttributes_p
               WHERE taxon_id IN (".$taxonIds.")";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    my %groupToSourceIds;
    my $numIds = 0;
    while(my ($sourceId, $group) = $sh->fetchrow_array()) {
	$numIds++;
	$groupToSourceIds{$group} = &addToList($groupToSourceIds{$group},$sourceId);
    }
    print "$numIds source Ids, ";
    return \%groupToSourceIds;
}

sub addToList {
    my ($listRef,$element) = @_;
    if (defined $listRef) {
	push @{$listRef}, $element;
    } else {
	$listRef = [$element];
    }
    return $listRef;
}

sub convertGroupsToSourceIds {
    my ($groups,$groupsToSourceIds) = @_;
    my %sourceIds;
    foreach my $group (keys %{$groups}) {
	foreach my $id (@{$groupsToSourceIds->{$group}}) {
	    $sourceIds{$id} = 1;
	}
    }
    return \%sourceIds;
}

sub createTable {
    my ($tableName,$sourceIds,$dbh) = @_;
    my $sql = "CREATE TABLE $tableName (SOURCE_ID VARCHAR2(50))";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    foreach my $sourceId (keys %{$sourceIds}) {
	$sql = "INSERT INTO $tableName (SOURCE_ID) VALUES ('$sourceId')";
	my $sh = $dbh->prepare($sql);
	$sh->execute();
    }	
}

sub finalSearchQuery {
    my ($tableName,$outputFile,$dbh) = @_;
    my $sql = "SELECT DISTINCT ta.source_id, ta.gene_source_id, 'Y' as matched_result, ta.project_id, ta.taxon_id 
               FROM webready.TranscriptAttributes_p ta, $tableName pp
               WHERE pp.source_id = ta.source_id";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    open(OUT,">",$outputFile) || die "Can't write to file '$outputFile'";;
    my $numIds = 0;
    while(my @row = $sh->fetchrow_array()) {
	$numIds++;
	print OUT join("\t",@row)."\n";
    }
    print "$numIds number of source Ids, ";
    close OUT;
}

sub connectToDb {
    my ($instance) = @_;
    my $dbiDsn = 'dbi:Oracle:' . $instance;
    my $dbh = DBI->connect($dbiDsn) or die DBI->errstr;
    $dbh->{RaiseError} = 1;
    $dbh->{AutoCommit} = 1;
    return $dbh;
}

1;
