#!/usr/bin/perl

use strict;
use DBI;
use DBD::Oracle;
use Getopt::Long;
use Data::Dumper;

my ($help, $databaseInstance, $genomicDir, $galaxyDir);

&GetOptions('help|h' => \$help,
            'database_instance=s' => \$databaseInstance,
            'genomic_files_dir=s' => \$genomicDir,
	    'galaxy_files_dir=s' => \$galaxyDir
            );


my $info = &initializeInfo();

&checkTaxonFile("$genomicDir/orthomclTaxons.txt",$info);
&checkEcOrgFile("$genomicDir/ec_organism.txt",$info);
&checkGroupFile("$genomicDir/orthomclGroups.txt","genomic",$info);
&checkCladesFile("$genomicDir/orthomclClades.txt",$info);
my ($galaxyGroupFile,$galaxyFastaFile) = &getGalaxyFiles($galaxyDir);
&checkGroupFile("$galaxyDir/$galaxyGroupFile","galaxy",$info);
&checkFastaFile("$galaxyDir/$galaxyFastaFile",$info);
my $dbh = &connectToDb($databaseInstance);
&checkGroupStatsInDb($dbh,$info);
$dbh->disconnect();
&finalCheck($info);

exit;




sub checkTaxonFile {
    my ($file,$info) = @_;

    print "\nChecking $file\n";

    my $core = `grep -oP 'C\$' $file | wc -l`;
    chomp($core);
    $info->{taxonCore} = $core;
    print "   Number of core organisms: $core";
    $info->{TotalTests}++;
    if ($core < 1 || $core > 150) {
	$info->{FailedTests}++;
	print " FAILED: There should be between 1-150\n";
    } else {
	print " Ok\n";
    }

    my $peripheral = `grep -oP 'P\$' $file | wc -l`;
    chomp($peripheral);
    $info->{taxonPeripheral} = $peripheral;
    print "   Number of peripheral organisms: $peripheral";
    $info->{TotalTests}++;
    if ($peripheral < 1) {
	$info->{FailedTests}++;
	print " FAILED: There is expected to be at least 1.\n";
    } else {
	print " Ok\n";
    }

    my $totalOrgs = $core + $peripheral;
    print "   Total number of organisms: $totalOrgs";
    $info->{TotalTests}++;
    if ($totalOrgs < $info->{ExpectedCore}) {
	$info->{FailedTests}++;
	print " FAILED: The total number is expected to be greater than $info->{ExpectedCore}, which is the expected number of core organisms.\n";
    } else {
	print " Ok\n";
    }

    my $z = `grep -oP 'Z\$' $file | wc -l`;
    chomp($z);
    print "   Number of Z category (taxonomic groups): $z";
    $info->{TotalTests}++;
    if ($z > 0) {
	$info->{FailedTests}++;
	print " FAILED: There should be none.\n";
    } else {
	print " Ok\n";
    }

    my $old = `grep -o '^[A-Za-z]{4}-old' $file | wc -l`;
    chomp($old);
    print "   Number of organisms with '-old': $old";
    $info->{TotalTests}++;
    if ($old != 0) {
	$info->{FailedTests}++;
	print " FAILED: There should be none.\n";
    } else {
	print " Ok\n";
    }

    my $rhiz = `grep -o '^rhiz' $file | wc -l`;
    chomp($rhiz);
    print "   Number of lines with 'rhiz': $rhiz";
    $info->{TotalTests}++;
    if ($rhiz != 0) {
	$info->{FailedTests}++;
	print " FAILED: There should be none.\n";
    } else {
	print " Ok\n";
    }

    my $rirr = `grep -o '^rirr' $file | wc -l`;
    chomp($rirr);
    print "   Number of lines with 'rirr': $rirr";
    $info->{TotalTests}++;
    if ($rirr != 1) {
	$info->{FailedTests}++;
	print " FAILED: There should be 1 line.\n";
    } else {
	print " Ok\n";
    }

}


sub checkEcOrgFile {
    my ($file,$info) = @_;

    print "\nChecking $file\n";

    open(my $inFh,'<', $file) or die "Unable to read file $file.\n";   

    my %ec; my %genera;
    my $numLines=0;
    while (my $line = <$inFh>) {
	next if ($line =~ /^\s/);
	chomp $line;
	my @array = split("\t",$line);
	die "ERROR:  File $file should only have 2 columns:\n$line" if (scalar @array != 2);
	$ec{$array[0]}++;
	$genera{$array[1]}++;
	$numLines++;
    }
    close $inFh;

    my $numEc = keys %ec;
    my $numGenera = keys %genera;

    print "   Number of lines in file: $numLines";
    $info->{TotalTests}++;
    if ($numLines < 229830) {
	$info->{FailedTests}++;
	print " FAILED: There were 229,830 lines in OG6r9, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }

    print "   Number of unique EC numbers: $numEc";
    $info->{TotalTests}++;
    if ($numEc < 3491) {
	$info->{FailedTests}++;
	print " FAILED: There were 3,491 EC numbers in OG6r9, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }

    print "   Number of unique Genera: $numGenera";
    $info->{TotalTests}++;
    if ($numGenera < 150) { 
	$info->{FailedTests}++;
	print " FAILED: There were 150 Genera in OG6r9, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }

}

sub checkGroupFile {
    my ($file,$type,$info) = @_;

    print "\nChecking $file\n";

    open(my $inFh,'<', $file) or die "Unable to read file $file.\n";   

    my $numCore=0; my $numPeripheral=0; my $numProteins=0;
    my %orgs; my %versions;

    while (my $line = <$inFh>) {
	next if ($line =~ /^\s/);
	chomp $line;
	my @array = split(/\s+/,$line);
	my $group = shift @array;
	if ($group =~ /(OG\d+)_/) {
	    my $groupVersion = $1;
	    $versions{$groupVersion} = 1;
	    $info->{$type}->{groupVersions}->{$groupVersion} = 1;
	    $numCore++;
	} elsif ($group =~ /(OG\d+r\d+)_/) {
	    my $groupVersion = $1;
	    $versions{$groupVersion} = 1;
	    $info->{$type}->{groupVersions}->{$groupVersion} = 1;
	    $numPeripheral++;
	} else {
	    die "ERROR: The ortholog group name is not in the expected format\n$line";
	}
	foreach my $protein (@array) {
	    if ($protein =~ /^([^\|]{4,8})\|/) {
		$orgs{$1}++;
		$numProteins++;
	    } else {
		die "ERROR: The protein name is not in the expected format: '$protein'\n$line";
	    }
	}
    }
    close $inFh;
    
    my $numVersions = keys %versions;
    my $numOrgs = keys %orgs;
    $info->{$type}->{groupOrgs} = $numOrgs;
    $info->{$type}->{groupCore} = $numCore;
    $info->{$type}->{groupPeripheral} = $numPeripheral;
    $info->{$type}->{groupProteins} = $numProteins;

    my $numOld=0; my $rirr="no"; my $rhiz="no";
    foreach my $org (keys %orgs) {
	if ($org =~ /-old/) {
	    $numOld++;
	} elsif ($org eq 'rirr') {
	    $rirr="yes";
	} elsif ($org eq 'rhiz') {
	    $rhiz="yes";
	}
    }
    $info->{$type}->{groupOld} = $numOld;

    print "    Number of group versions: $numVersions   Versions:  ";
    print "$_ " foreach (keys %versions);
    $info->{TotalTests}++;
    if ($numVersions != 2) {
	$info->{FailedTests}++;
	print " FAILED: There should only be two versions of groups (e.g., OG6_xxxxxx and OGr9_xxxxxx)\n";
    } else {
	print " Ok\n";
    }

    print "    Number of core groups: $numCore";
    $info->{TotalTests}++;
    if ($numCore != 495339) {
	$info->{FailedTests}++;
	print " FAILED: There has been 495,339 core groups in OG6 past releases and this should stay same in future OG6 releases.\n";
    } else {
	print " Ok\n";
    }

    print "    Number of peripheral groups: $numPeripheral";
    $info->{TotalTests}++;
    if ($numPeripheral < 365503) {
	$info->{FailedTests}++;
	print " FAILED: There were 365,503 peripheral groups in the OG6r9 release, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }

    print "    Number of unique organisms: $numOrgs";
    $info->{TotalTests}++;
    if ($numOrgs < 650 && $type eq "genomic") {
	$info->{FailedTests}++;
	print " FAILED: There should at least 650 organisms, which were in OG6r9, although intentional removal of organisms may cause less.\n";
    } elsif ($numOrgs < 684 && $type eq "galaxy") {
	$info->{FailedTests}++;
	print " FAILED: There should at least 684 organisms, which were in OG6r9, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }

    print "    Number of -old organisms: $numOld";
    $info->{TotalTests}++;
    if ($numOld > 0 && $type eq "genomic") {
	$info->{FailedTests}++;
	print " FAILED: There should not be any -old organisms in this file\n";
    } else {
	print " Ok\n";
    }

    print "    'rirr' organism present: $rirr";
    $info->{TotalTests}++;
    if ($rirr eq "no" && $type eq "genomic") {
	$info->{FailedTests}++;
	print " FAILED: 'rirr' should be present.\n";
    } elsif ($rirr eq "yes" && $type eq "galaxy") {
	$info->{FailedTests}++;
	print " FAILED: 'rirr' should be absent.\n";
    } else {
	print " Ok\n";
    }

    print "    'rhiz' organism present: $rhiz";
    $info->{TotalTests}++;
    if ($rhiz eq "yes" && $type eq "genomic") {
	$info->{FailedTests}++;
	print " FAILED: 'rhiz' should be absent.\n";
    } elsif ($rhiz eq "no" && $type eq "galaxy") {
	$info->{FailedTests}++;
	print " FAILED: 'rhiz' should be present.\n";
    } else {
	print " Ok\n";
    }

    print "    Number of proteins: $numProteins";
    $info->{TotalTests}++;
    if ($numProteins < 6544376 && $type eq "genomic") {
	$info->{FailedTests}++;
	print " FAILED: There were 6,544,376 proteins in release OG6r9, although intentional removal of organisms may cause less.\n";
    } elsif ($numProteins < 2453012 && $type eq "galaxy") {
	$info->{FailedTests}++;
	print " FAILED: There were 2,453,012 proteins in release OG6r9, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }

}

sub checkCladesFile {
    my ($file,$info) = @_;

    print "\nChecking $file\n";

    open(my $inFh,'<', $file) or die "Unable to read file $file.\n";   

    my %clades;
    my $numLines=0;
    while (my $line = <$inFh>) {
	next if ($line =~ /^\s/);
	if ($line =~ /\s([A-Z]{4})\s/) {
	    $clades{$1} = 1;
	}
	$numLines++;
    }
    close $inFh;

    my $numClades = keys %clades;

    print "    Number of lines: $numLines";
    $info->{TotalTests}++;
    if ($numLines != 48) {
	$info->{FailedTests}++;
	print " FAILED: 48 lines are expected.\n";
    } else {
	print " Ok\n";
    }

    print "    Number of clades: $numClades";
    $info->{TotalTests}++;
    if ($numClades != 47) {
	$info->{FailedTests}++;
	print " FAILED: 47 clades are expected.\n";
    } else {
	print " Ok\n";
    }

}

sub checkFastaFile {
    my ($file,$info) = @_;

    print "\nChecking $file\n";

    open(my $inFh,'<', $file) or die "Unable to read file $file.\n";   

    my $numProteins=0;
    my %orgs;
    while (my $line = <$inFh>) {
	if ($line =~ /^>([^\|]{4,8})\|/) {
	    $orgs{$1}++;
	    $numProteins++;
	}
    }
    close $inFh;

    my $numOrgs = keys %orgs;
    my $numOld=0; my $rirr="no"; my $rhiz="no";
    foreach my $org (keys %orgs) {
	if ($org =~ /-old/) {
	    $numOld++;
	} elsif ($org eq 'rirr') {
	    $rirr="yes";
	} elsif ($org eq 'rhiz') {
	    $rhiz="yes";
	}
    }
    $info->{fastaOrgs} = $numOrgs;
    $info->{fastaProteins} = $numProteins;
    $info->{fastaOldOrgs} = $numOld;

    print "    Number of unique organisms: $numOrgs";
    $info->{TotalTests}++;
    if ($numOrgs < 650) {
	$info->{FailedTests}++;
	print " FAILED: There should at least 650 organisms, which were in OG6r9, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }

    print "    Number of -old organisms: $numOld Ok\n";
    $info->{TotalTests}++;

    print "    'rirr' organism present: $rirr";
    $info->{TotalTests}++;
    if ($rirr eq "yes") {
	$info->{FailedTests}++;
	print " FAILED: 'rirr' should be absent.\n";
    } else {
	print " Ok\n";
    }

    print "    'rhiz' organism present: $rhiz";
    $info->{TotalTests}++;
    if ($rhiz eq "no") {
	$info->{FailedTests}++;
	print " FAILED: 'rhiz' should be present.\n";
    } else {
	print " Ok\n";
    }

    print "    Number of proteins: $numProteins";
    $info->{TotalTests}++;
    if ($numProteins < 2453012) {
	$info->{FailedTests}++;
	print " FAILED: There were 2,453,012 proteins in release OG6r9, although intentional removal of organisms may cause less.\n";
    } else {
	print " Ok\n";
    }
}

sub getGalaxyFiles {
    my ($galaxyDir) = @_;
    print "\nGetting file names in the Galaxy directory: $galaxyDir\n";
    opendir my $dir, $galaxyDir or die "Cannot open directory: $!";
    my @files = readdir $dir;
    closedir $dir;
    my ($groupFile,$fastaFile);
    foreach my $file (@files) {
	if ($file =~ /group/i) {
	    die "There are two group files in this directory" if ($groupFile);
	    $groupFile = $file;
	    print "   Groups file: $groupFile\n";
	}
	if ($file =~ /sequences/i) {
	    die "There are two sequence files in this directory" if ($fastaFile);
	    $fastaFile = $file;
	    print "   Sequence files: $fastaFile\n";
	}
    }
    die "Did not find the group file in this directory" if (! $groupFile);
    die "Did not find the sequence file in this directory" if (! $fastaFile);
    return ($groupFile,$fastaFile);
}

sub initializeInfo {
    my %info = ( 
	       ExpectedCore => 150,
	       TotalTests => 0,
	       FailedTests => 0
	);
    return \%info;
}

sub finalCheck {
    my ($info) = @_;

    my $totalTaxon = $info->{taxonCore} + $info->{taxonPeripheral};
    $info->{TotalTests}++;
    print "\nTesting that number organisms in orthomclTaxons.txt file is same as in orthomclGroups.txt file. ";
    if ($totalTaxon != $info->{genomic}->{groupOrgs}) {
	$info->{FailedTests}++;
	print " FAILED: $totalTaxon in orthomclTaxons.txt file and $info->{genomic}->{groupOrgs} in orthomclGroups.txt file\n";
    } else {
	print " Ok.\n";
    }

    print "Testing that number organisms in orthomclTaxons.txt file is <= than in OGXrX_groups.txt file. ";
    $info->{TotalTests}++;
    if ($totalTaxon > $info->{galaxy}->{groupOrgs}) {
	$info->{FailedTests}++;
	print " FAILED: $totalTaxon in orthomclTaxons.txt file and $info->{galaxy}->{groupOrgs} in OGXrX_groups.txt file\n";
    } else {
	print " Ok.\n";
    }

    my $expectedOld = $info->{ExpectedCore} - $info->{taxonCore};
    $info->{TotalTests}++;
    print "There are $info->{ExpectedCore} original core orgs but $info->{taxonCore} are remaining. Thus there should be $expectedOld -old orgs. ";
    if ($expectedOld != $info->{galaxy}->{groupOld}) {
	$info->{FailedTests}++;
	print " FAILED: There are $info->{galaxy}->{groupOld} -old orgs in OGXrX_groups.txt file\n";
    } else {
	print " Ok.\n";
    }

    print "Testing that number core groups in orthomclGroups.txt file is same as in OGXrX_groups.txt file. ";
    $info->{TotalTests}++;
    if ($info->{genomic}->{groupCore} != $info->{galaxy}->{groupCore}) {
	$info->{FailedTests}++;
	print " FAILED: There are $info->{genomic}->{groupCore} in orthomclGroups.txt file and $info->{galaxy}->{groupCore} in OGXrX_groups.txt file\n";
    } else {
	print " Ok.\n";
    }

    print "Testing that number peripheral groups in orthomclGroups.txt file is same as in OGXrX_groups.txt file. ";
    $info->{TotalTests}++;
    if ($info->{genomic}->{groupPeripheral} != $info->{galaxy}->{groupPeripheral}) {
	$info->{FailedTests}++;
	print " FAILED: There are $info->{genomic}->{groupPeripheral} in orthomclGroups.txt file and $info->{galaxy}->{groupPeripheral} in OGXrX_groups.txt file\n";
    } else {
	print " Ok.\n";
    }

    print "Testing that number orgs is same in OGXrX_sequences.fasta and OGXrX_groups.txt files. ";
    $info->{TotalTests}++;
    if ($info->{fastaOrgs} != $info->{galaxy}->{groupOrgs}) {
	$info->{FailedTests}++;
	print " FAILED: There are $info->{fastaOrgs} in OGXrX_sequences.fasta file and $info->{galaxy}->{groupOrgs} in OGXrX_groups.txt file\n";
    } else {
	print " Ok.\n";
    }

    print "Testing that number proteins is same in OGXrX_sequences.fasta and OGXrX_groups.txt files. ";
    $info->{TotalTests}++;
    if ($info->{fastaProteins} != $info->{galaxy}->{groupProteins}) {
	$info->{FailedTests}++;
	print " FAILED: There are $info->{fastaProteins} in OGXrX_sequences.fasta file and $info->{galaxy}->{groupProteins} in OGXrX_groups.txt file\n";
    } else {
	print " Ok.\n";
    }

    print "Testing that number proteins in OGXrX_sequences.fasta file is less than in orthomclGroups.txt file. ";
    $info->{TotalTests}++;
    if ($info->{fastaProteins} > $info->{genomic}->{groupProteins}) {
	$info->{FailedTests}++;
	print " FAILED: There are $info->{fastaProteins} in OGXrX_sequences.fasta file and $info->{genomic}->{groupProteins} in OGXrX_groups.txt file\n";
    } else {
	print " Ok.\n";
    }

    my $match=1;
    foreach my $version (keys %{$info->{genomic}->{groupVersions}}) {
	$match=0 if (! exists $info->{galaxy}->{groupVersions}->{$version});
    }
    foreach my $version (keys %{$info->{galaxy}->{groupVersions}}) {
	$match=0 if (! exists $info->{genomic}->{groupVersions}->{$version});
    }
    print "Testing that versions are same in orthomclGroups.txt and OGXrX_groups.txt files. ";
    $info->{TotalTests}++;
    if ($match == 0) {
	$info->{FailedTests}++;
	print " FAILED: The versions do not match. See above for versions present in these files.\n";
    } else {
	print " Ok.\n";
    }

    print "\n\nSUMMARY:  $info->{FailedTests} out of $info->{TotalTests} tests failed.\n\n";
}

sub checkGroupStatsInDb {
    my ($dbh,$info) = @_;

    print "\nTesting apidb.orthologgroup table in the database.\n";

    my $numGroups = &getCountFromDb("SELECT COUNT(*) FROM apidb.orthologgroup");
    print "   Number of groups (C and P are duplicate): $numGroups";
    $info->{TotalTests}++;
    if ($numGroups < 1356181) {
	$info->{FailedTests}++;
	print " FAILED:  There were 1,356,181 in OG6r9, though the number could decrease if orgs were intentionally removed.\n";
    } else {
	print " Ok.\n";
    }

    my $numGroupsNoMember = &getCountFromDb("SELECT COUNT(*) FROM apidb.orthologgroup WHERE number_of_members IS NULL OR number_of_members = 0");
    print "   Number of groups with no member: $numGroupsNoMember";
    $info->{TotalTests}++;
    if ($numGroupsNoMember != 0) {
	$info->{FailedTests}++;
	print " FAILED:  All groups should have at least 1 member.\n";
    } else {
	print " Ok.\n";
    }

    my $numGroupsOneMember = &getCountFromDb("SELECT COUNT(*) FROM apidb.orthologgroup WHERE number_of_members = 1");
    print "   Number of groups with only 1 member: $numGroupsOneMember";
    $info->{TotalTests}++;
    if ($numGroupsOneMember == 0) {
	$info->{FailedTests}++;
	print " FAILED:  All groups should have at least 1 member.\n";
    } else {
	print " Ok.\n";
    }

    my $numGroupsOneMemberMatchPairs = &getCountFromDb("SELECT COUNT(*) FROM apidb.orthologgroup WHERE number_of_members = 1 AND number_of_match_pairs IS NOT NULL AND number_of_match_pairs != 0");
    print "   Number of groups with only 1 member and with 1 or more match pairs: $numGroupsOneMemberMatchPairs";
    $info->{TotalTests}++;
    if ($numGroupsOneMemberMatchPairs != 0) {
	$info->{FailedTests}++;
	print " FAILED:  All groups 1 member should not have any match pairs.\n";
    } else {
	print " Ok.\n";
    }

    my $numGroupsTwoPlusMember = &getCountFromDb("SELECT COUNT(*) FROM apidb.orthologgroup WHERE number_of_members > 1");
    print "   Number of groups with 2 or more members: $numGroupsTwoPlusMember";
    $info->{TotalTests}++;
    if ($numGroupsTwoPlusMember == 0) {
	$info->{FailedTests}++;
	print " FAILED:  There should be many groups with 2 or more members.\n";
    } else {
	print " Ok.\n";
    }

    my $numGroupsTwoPlusMemberMatchPairs = &getCountFromDb("SELECT COUNT(*) FROM apidb.orthologgroup WHERE number_of_members > 1 AND number_of_match_pairs IS NOT NULL AND number_of_match_pairs != 0");
    print "   Number of groups with 2 or more members and with 1 or more match pairs: $numGroupsTwoPlusMemberMatchPairs";
    $info->{TotalTests}++;
    if ($numGroupsTwoPlusMemberMatchPairs != $numGroupsTwoPlusMember) {
	$info->{FailedTests}++;
	print " FAILED:  All of these groups should have at least 1 match pair.\n";
    } else {
	print " Ok.\n";
    }
}

sub getCountFromDb {
    my ($sql) = @_;
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    my $count = "";
    while (my @a = $sh->fetchrow_array()) {
	my $numCols = scalar @a;
	die "There should only be one row and one column of data from the database\nSQL: $sql\nOne row of results: @a" if ($count ne "" || $numCols != 1);
	$count = $a[0];
    }
    return $count;
}


sub connectToDb {
  my ($instance) = @_;

  my $dbiDsn = 'dbi:Oracle:' . $instance;
  my $dbh = DBI->connect($dbiDsn) or die DBI->errstr;
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 0;

  return $dbh
}



1;
