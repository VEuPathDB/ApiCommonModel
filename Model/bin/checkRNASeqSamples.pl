#!/usr/bin/perl

use strict;

use DBI;
use DBD::Oracle;

use Getopt::Long;

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
my $dbProfiles = &queryForProfiles($dbh);

my ($legacyDbh, $legacyDbProfiles);
if($legacyDatabaseInstance) {

  &makeDirectoryUnlessExists($legacyDatabaseDirectory);
  $legacyDbh = &connectToDb($legacyDatabaseInstance);
  $legacyDbProfiles = &queryForProfiles($legacyDbh);

}

foreach my $dataset (keys %$dbProfiles) {
  my @da = split("_", $dataset);
  my $orgAbbrev = $da[0];

  my $orgDirectory = "$databaseDirectory/$orgAbbrev";
  my $legacyOrgDirectory = "$legacyDatabaseDirectory/$orgAbbrev";

  &makeDirectoryUnlessExists($orgDirectory);
  &makeDirectoryUnlessExists($legacyOrgDirectory) if($legacyDatabaseInstance);
  
  foreach my $profile (keys %{$dbProfiles->{$dataset}}) {
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
        print STDERR "WARNING:  Could not find a matching dataset for dataset=$dataset and profile=$profile\n";
        next;
      }

      unless(-e $legacyFile) {
        my $legacyFh;
        open($legacyFh, ">$legacyFile") or die "Cannot open file $legacyFile for writing: $!";
        &printHeader($legacyStudyId, $legacyFh, $legacyDbh);
        &printData($legacyStudyId, $legacyFh, $legacyDbh);
        close $legacyFh;
      }

      my $outputFile = "$orgDirectory/corrlations_${studyId}";
      my $cmd = "Rscript rnaSeqCorrTwoExpts $file $legacyFile $outputFile";
      system($cmd);
    }
  }
}

$dbh->disconnect();
if($legacyDatabaseInstance) {
  $legacyDbh->disconnect();
}

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

  while(my ($dataset, $profileSet, $studyId) = $sh->fetchrow_array()) {
    $dataset =~ s/_ebi_/_/;
    $profileSet =~ s/ - (tpm|fpkm) - / - exprval - /;

    $rv{$dataset}->{$profileSet} = $studyId;
  }
  return \%rv;
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
