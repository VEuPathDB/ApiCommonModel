#!/usr/bin/perl

use strict;

use DBI;
use DBD::Oracle;

use Getopt::Long;

use CBIL::Util::V;

use Data::Dumper;

my ($help, $databaseInstance, $legacyDatabaseInstance, $workingDir);

&GetOptions('help|h' => \$help,
            'database_instance=s' => \$databaseInstance,
            'legacy_database_instance=s' => \$legacyDatabaseInstance,
            'working_dir=s' => \$workingDir,
            );


my $databaseDirectory = "$workingDir/$databaseInstance";
my $legacyDatabaseDirectory = "$workingDir/$legacyDatabaseInstance";

&makeDirectoryUnlessExists($databaseDirectory);
my $dbh = &connectToDb($databaseInstance);
my ($dbProfiles, $dbStrandedDatasets) = &queryForProfiles($dbh);

my ($legacyDbh, $legacyDbProfiles, $legacyDbStrandedDatasets);
if($legacyDatabaseInstance) {

  &makeDirectoryUnlessExists($legacyDatabaseDirectory);
  $legacyDbh = &connectToDb($legacyDatabaseInstance);
  ($legacyDbProfiles, $legacyDbStrandedDatasets) = &queryForProfiles($legacyDbh);
}

my $numProfiles=0;
my $numProfilesStrandError=0;
my $numProfilesMatchingError=0;
my $numProfilesSampleError=0;
foreach my $dataset (keys %$dbProfiles) {
  my @da = split("_", $dataset);
  my $orgAbbrev = $da[0];

  my $orgDirectory = "$databaseDirectory/$orgAbbrev";
  my $legacyOrgDirectory = "$legacyDatabaseDirectory/$orgAbbrev";

  &makeDirectoryUnlessExists($orgDirectory);
  &makeDirectoryUnlessExists($legacyOrgDirectory) if($legacyDatabaseInstance);
  
  foreach my $profile (keys %{$dbProfiles->{$dataset}}) {
    $numProfiles++;

    my $studyId = $dbProfiles->{$dataset}->{$profile};
    my $file = "$orgDirectory/${studyId}.txt";

    unless(-e $file) {
      my $fh;
      open($fh, ">$file") or die "Cannot open file $file for writing: $!";
      &printHeader($studyId, $fh, $dbh);
      &printData($studyId, $fh, $dbh);
      close $fh;
    }

    if($legacyDatabaseInstance) {
      my $legacyStudyId = $legacyDbProfiles->{$dataset}->{$profile};

      my $legacyFile = "$legacyOrgDirectory/${legacyStudyId}.txt";

      unless($legacyStudyId) {
        my $isStrandedInDb = $dbStrandedDatasets->{$dataset} ? 'stranded' : 'unstranded';
        my $isStrandedInLegacyDb = $legacyDbStrandedDatasets->{$dataset} ? 'stranded' : 'unstranded';

        if($isStrandedInDb ne $isStrandedInLegacyDb) {
          print STDERR "WARN:  Dataset $dataset is $isStrandedInDb in first instance but $isStrandedInLegacyDb in legacy db\n\n";
	  $numProfilesStrandError++;
        }
        else {
          print STDERR "WARN:  Could not find a matching dataset for dataset=$dataset and profile=$profile\n\n";
	  $numProfilesMatchingError++;
        }
        next;
      }

      unless(-e $legacyFile) {
        my $legacyFh;
        open($legacyFh, ">$legacyFile") or die "Cannot open file $legacyFile for writing: $!";
        &printHeader($legacyStudyId, $legacyFh, $legacyDbh);
        &printData($legacyStudyId, $legacyFh, $legacyDbh);
        close $legacyFh;
      }

      my $outputFile = "$orgDirectory/correlations_${studyId}.txt";
      my $cmd = "rnaSeqCorrTwoExpts.R $file $legacyFile $outputFile";
      system($cmd);

      $numProfilesSampleError += makeReportFromOutputFile($outputFile, $dataset);
    }
  }
}

$dbh->disconnect();
if($legacyDatabaseInstance) {
  $legacyDbh->disconnect();
}

my $numProfilesPassedTests = $numProfiles - $numProfilesStrandError - $numProfilesMatchingError - $numProfilesSampleError;
print STDERR "\n\n================SUMMARY================\n";
print STDERR "Number of profiles: $numProfiles,  Number passed test: $numProfilesPassedTests\n\n";
print STDERR "Number of profiles with strand error: $numProfilesStrandError\n";
print STDERR "Number of profiles without corresponding legacy profile: $numProfilesMatchingError\n";
print STDERR "Number of profiles with poor sample correlation: $numProfilesSampleError\n";


sub printData {
  my ($studyId, $fh, $dbh) = @_;

  my $sql = "select ga.source_id, p.profile_as_string 
from apidbtuning.profile  p, apidbtuning.geneattributes ga
where p.profile_study_id = $studyId 
and profile_type = 'values' 
and ga.source_id = p.source_id (+)
order by ga.source_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my @a = $sh->fetchrow_array()) {
    print $fh join("\t", @a) . "\n";
  }
}


sub makeReportFromOutputFile {
  my ($file, $dataset) = @_;

  my $failedTest=0;  

  open(FILE, $file) or die "Cannot open file $file for reading: $!";

  print STDERR "Reporting on dataset $dataset (file $file)\n";

  my $header = <FILE>;
  chomp $header;
  my @headers = split(/\t/, $header);

  my %sampleIndexes;

  for(my $i = 1; $i < scalar @headers; $i++) {
    my $sampleName = $headers[$i];
    $sampleIndexes{$sampleName} = $i;
  }

  while(<FILE>) {
    chomp;
    my @a = split(/\t/, $_);
    my $sampleName = shift @a; 

    my $index = $sampleIndexes{$sampleName} - 1;
    my $value = $a[$index];

    my $maxValue = CBIL::Util::V::max(@a);

    my $threshold = 0.9;
    my $selfThreshold = 0.99;
   if ($value != $maxValue && $value < $selfThreshold) {
      print STDERR "\nERROR:  Sample '$sampleName' self-correlation is $value but the max pairwise correlation is $maxValue.\n";
      $failedTest=1;
   } elsif ($value < $threshold) {
       print STDERR "\nERROR:  Sample '$sampleName' self-correlation of $value is below the threshold of $threshold.\n";
       $failedTest=1;
   } else {
      print STDERR "Ok.";
   }
  }
  print STDERR "\n\n";

  return $failedTest;
}



sub printHeader {
  my ($studyId, $fh, $dbh) = @_;

  my $sql = "select protocol_app_node_name from apidbtuning.profilesamples where study_id = $studyId and profile_type = 'values' order by node_order_num";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my @a;
  while(my ($name) = $sh->fetchrow_array()) {
    push @a, $name;
  }

  print $fh "Gene\t" . join("\t", @a) . "\n";
}


sub makeDirectoryUnlessExists {
  my ($dir) = @_;

  mkdir $dir unless(-d $dir);

}


sub queryForProfiles {
  my ($dbh) = @_;

  my %rv;

  my $sql = "select dataset_name, profile_set_name, profile_study_id
from apidbtuning.profiletype 
where dataset_type = 'transcript_expression' 
and dataset_subtype = 'rnaseq' 
and profile_type = 'values'
and profile_set_name like '% unique]'
";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  my %strandedDatasets;

  while(my ($dataset, $profileSet, $studyId) = $sh->fetchrow_array()) {
    my $isStranded = $profileSet =~ / - (firststrand|secondstrand) - /;

    $dataset =~ s/_ebi_/_/;
    $profileSet =~ s/ - (tpm|fpkm) - / - exprval - /;

    $rv{$dataset}->{$profileSet} = $studyId;

    $strandedDatasets{$dataset} = $isStranded;
  }
  return \%rv, \%strandedDatasets;
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
