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

my $numDatasets=0;
my $numDatasetsWithError=0;
foreach my $dataset (keys %$dbProfiles) {
    $numDatasets++;
    my $sumFiles;
    my $datasetError;

    print STDERR "\n\n****** Reporting on DATASET '$dataset' ******\n";
    my $isStrandedInDb = $dbStrandedDatasets->{$dataset} ? 'stranded' : 'unstranded';
    print STDERR "   This dataset is $isStrandedInDb.  Profiles:\n";
    my $numProfiles = scalar keys %{$dbProfiles->{$dataset}};
    if ($numProfiles == 0) {
	print STDERR "ERROR: Could not find any profiles for this dataset.\n";
	$datasetError=1;
    }

    my $profiles; # $profiles -> legacy/new -> profileName ->id -> id (strand -> first)
    my $numScaled=0;
    foreach my $profile (keys %{$dbProfiles->{$dataset}}) {
	print STDERR "          $profile\n";
	$numScaled++ if ($profile =~ /scaled/);
	if ($profile =~ /firststrand/) {
	    $profiles->{new}->{$profile}->{id} = $dbProfiles->{$dataset}->{$profile};
	    $profiles->{new}->{$profile}->{strand} = "first";
	} elsif ($profile =~ /secondstrand/) {
	    $profiles->{new}->{$profile}->{id} = $dbProfiles->{$dataset}->{$profile};
	    $profiles->{new}->{$profile}->{strand} = "second";
	} elsif ($profile =~ /unstranded/) {
	    $profiles->{new}->{$profile}->{id} = $dbProfiles->{$dataset}->{$profile};
	    $profiles->{new}->{$profile}->{strand} = "unstranded";
	} else {
	    $profiles->{new}->{$profile}->{id} = $dbProfiles->{$dataset}->{$profile};
	    $profiles->{new}->{$profile}->{strand} = "unknown";
	    print STDERR "ERROR: It is not clear whether $profile is stranded.\n";
	    $datasetError=1; 
	}
    }
    
    if ($numScaled > 2) {
	print STDERR "ERROR: Unexpectedly, there are more than 2 scaled profiles\n";
	$datasetError=1;
    }
    if (($numProfiles-$numScaled) > 2) {
	print STDERR "ERROR: Unexpectedly, there are more than 2 non-scaled profiles\n";
	$datasetError=1;
    }

    my $isStrandedInLegacyDb;
    if ( $legacyDatabaseInstance ) {
	if ( ! exists $legacyDbProfiles->{$dataset}) {
	    print STDERR "   WARN:  Could not find a matching legacy dataset for dataset=$dataset\n";
	    $numDatasetsWithError++;
	    next;
	} else {
	    print STDERR "   Found a matching legacy dataset.\n";
	    $isStrandedInLegacyDb = $legacyDbStrandedDatasets->{$dataset} ? 'stranded' : 'unstranded';
	    print STDERR "   This dataset is $isStrandedInLegacyDb.  Profiles:\n";
	    my $numLegacyProfiles = scalar keys %{$legacyDbProfiles->{$dataset}};
	    if ($numLegacyProfiles == 0) {
		print STDERR "ERROR: Could not find any profiles for this dataset.\n";
		$datasetError=1;
	    }

	    my $numLegacyScaled=0;
	    foreach my $profile (keys %{$legacyDbProfiles->{$dataset}}) {
		print STDERR "          $profile\n";
		$numLegacyScaled++ if ($profile =~ /scaled/);
		if ($profile =~ /firststrand/) {
		    $profiles->{legacy}->{$profile}->{id} = $legacyDbProfiles->{$dataset}->{$profile};
		    $profiles->{legacy}->{$profile}->{strand} = "first";
		} elsif ($profile =~ /secondstrand/) {
		    $profiles->{legacy}->{$profile}->{id} = $legacyDbProfiles->{$dataset}->{$profile};
		    $profiles->{legacy}->{$profile}->{strand} = "second";
		} elsif ($profile =~ /unstranded/) {
		    $profiles->{legacy}->{$profile}->{id} = $legacyDbProfiles->{$dataset}->{$profile};
		    $profiles->{legacy}->{$profile}->{strand} = "unstranded";
		} else {
		    $profiles->{legacy}->{$profile}->{id} = $legacyDbProfiles->{$dataset}->{$profile};
		    $profiles->{legacy}->{$profile}->{strand} = "unknown";
		    print STDERR "ERROR: It is not clear whether $profile is stranded.\n";
		    $datasetError=1; 
		}
	    }
	
	    if ($numLegacyScaled > 2) {
		print STDERR "ERROR: Unexpectedly, there are more than 2 scaled profiles\n";
		$datasetError=1;
	    }
	    if (($numLegacyProfiles-$numLegacyScaled) > 2) {
		print STDERR "ERROR: Unexpectedly, there are more than 2 non-scaled profiles\n";
		$datasetError=1;
	    }
	  
	    foreach my $profile (keys %{$dbProfiles->{$dataset}}) {
		if (! exists $legacyDbProfiles->{$dataset}->{$profile} ) {
		    print STDERR "ERROR: The new profile $profile does not exist in the legacy database.\n";                                                                  
		    $datasetError=1;
		}
	    }
	    foreach my $profile (keys %{$legacyDbProfiles->{$dataset}}) {
		if (! exists $dbProfiles->{$dataset}->{$profile} ) {
		    print STDERR "ERROR: The legacy profile $profile does not exist in the new database.\n";                                                                  
		    $datasetError=1;
		}
	    }
	    
	    if($isStrandedInDb ne $isStrandedInLegacyDb) {
		print STDERR "WARN:  Dataset $dataset is $isStrandedInDb in first instance but $isStrandedInLegacyDb in legacy db\n";
		$sumFiles = $isStrandedInDb eq "stranded" ? "new" : "legacy";
		print STDERR "       I will sum the two $sumFiles stranded profiles into one file, then calculate correlations to the unstranded file.\n";
		$datasetError=1;
	    }
        }
    }

    my @da = split("_", $dataset);
    my $orgAbbrev = $da[0];
    
    my $orgDirectory = "$databaseDirectory/$orgAbbrev";
    my $legacyOrgDirectory = "$legacyDatabaseDirectory/$orgAbbrev";

    &makeDirectoryUnlessExists($orgDirectory);
    &makeDirectoryUnlessExists($legacyOrgDirectory) if($legacyDatabaseInstance);

    foreach my $profileName (keys %{$profiles->{new}}) {
	my $studyId = $profiles->{new}->{$profileName}->{id};
	if (! $studyId) {
	    print STDERR "ERROR:    Could not find a studyId for profile $profileName\n";
	    $datasetError=1;
	    next;
	}
	my $file = "$orgDirectory/${studyId}.txt";
	
	unless(-e $file) {
	    my $fh;
	    open($fh, ">$file") or die "Cannot open file $file for writing: $!";
	    &printHeader($studyId, $fh, $dbh);
	    &printData($studyId, $fh, $dbh);
	    close $fh;
	}
    }

    if($legacyDatabaseInstance) {
	foreach my $profileName (keys %{$profiles->{legacy}}) {
	    my $studyId = $profiles->{legacy}->{$profileName}->{id};
	    if (! $studyId) {
		print STDERR "ERROR:    Could not find a studyId for profile $profileName\n";
		$datasetError=1;
		next;
	    }

	    my $file = "$legacyOrgDirectory/${studyId}.txt";
	    
	    unless(-e $file) {
		my $fh;
		open($fh, ">$file") or die "Cannot open file $file for writing: $!";
		&printHeader($studyId, $fh, $legacyDbh);
		&printData($studyId, $fh, $legacyDbh);
		close $fh;
	    }
	}
    }

    my $seenAlready;
    my $numCorrFailedUnstranded=0;
    my @correlationsUnstranded;
    my $correlations;
    foreach my $profileName (keys %{$profiles->{new}}) {
	my $studyId = $profiles->{new}->{$profileName}->{id};
	my $file = "$orgDirectory/${studyId}.txt";
	my $legacyStudyId;
	my $legacyFile;
	
	my $studyIdTwo;   # get other strand so can check if mix-up
	my $fileTwo; 
	my $legacyStudyIdTwo;
	my $legacyFileTwo;
	my $newProfileName;

	if (exists $profiles->{legacy}->{$profileName}) {
	    $legacyStudyId = $profiles->{legacy}->{$profileName}->{id};
	    $legacyFile = "$legacyOrgDirectory/${legacyStudyId}.txt";
	    $newProfileName = $profileName;
	    my $seenProfileName;
	    if ( $newProfileName =~ /(firststrand|secondstrand)/) {
		my $strandType = $1;
		if ($newProfileName =~ /^(.+)$strandType/) {
		    $seenProfileName = $1;
		    next if (exists $seenAlready->{$seenProfileName});         ## only deal with stranded profiles once
		    $seenAlready->{$seenProfileName} = 1;
		    if ( $newProfileName =~ /firststrand/) {
			$newProfileName =~ s/firststrand/secondstrand/;
		    } elsif ( $newProfileName =~ /secondstrand/) {
			$newProfileName =~ s/secondstrand/firststrand/;
		    }
		    $studyIdTwo = $profiles->{new}->{$newProfileName}->{id};
		    $fileTwo = "$orgDirectory/${studyIdTwo}.txt";
		    $legacyStudyIdTwo = $profiles->{legacy}->{$newProfileName}->{id};
		    $legacyFileTwo = "$legacyOrgDirectory/${legacyStudyIdTwo}.txt";
		}
	    }
	} elsif ( $sumFiles eq "legacy") {            ### legacy is stranded and new is unstranded
	    $newProfileName = $profileName;
	    $newProfileName =~ s/unstranded/firststrand/;
	    my $firstStrandId = $profiles->{legacy}->{$newProfileName}->{id};
	    my $firstStrandFile = "$legacyOrgDirectory/${firstStrandId}.txt";
	    $newProfileName =~ s/firststrand/secondstrand/;
	    my $secondStrandId = $profiles->{legacy}->{$newProfileName}->{id};
	    my $secondStrandFile = "$legacyOrgDirectory/${secondStrandId}.txt";
	    $legacyFile = $legacyOrgDirectory."/combined_".$firstStrandId."_".$secondStrandId.".txt";
	    my @fileNames = ($firstStrandFile,$secondStrandFile);
	    print STDERR "            Combining\n";
	    print STDERR "                $_\n" foreach (@fileNames);
	    print STDERR "            into this file: $legacyFile\n";
	    &combineFiles(\@fileNames,$legacyFile);
	} elsif ( $sumFiles eq "new" && $profileName =~ /secondstrand/) {  # legacy is unstranded and new is stranded, only do this for secondstrand
	    $newProfileName = $profileName;
	    my $firstStrandId = $studyId;
	    my $firstStrandFile = "$orgDirectory/${firstStrandId}.txt";
	    $newProfileName =~ s/firststrand/secondstrand/;
	    my $secondStrandId = $profiles->{new}->{$newProfileName}->{id};
	    my $secondStrandFile = "$orgDirectory/${secondStrandId}.txt";
	    $file = $orgDirectory."/combined_".$firstStrandId."_".$secondStrandId.".txt";
	    my @fileNames = ($firstStrandFile,$secondStrandFile);
	    print STDERR "            Combining\n";
	    print STDERR "                $_\n" foreach (@fileNames);
	    print STDERR "            into this file: $file\n";
	    &combineFiles(\@fileNames,$file);
	    $newProfileName =~ s/secondstrand/unstranded/; 
	    $legacyStudyId = $profiles->{legacy}->{$newProfileName}->{id};
	    $legacyFile = "$legacyOrgDirectory/${legacyStudyId}.txt";
	}
	else {
	    print STDERR "ERROR:   Skipping correlations because unable to find matching profile for $profileName\n";
	    $numDatasetsWithError++;
	    next;
	}

	print STDERR "\n   Testing correlations of profile $profileName.\n"; 
	my $outputFile = "$orgDirectory/correlations_${studyId}.txt";
	print STDERR "          File containing all correlations: $outputFile\n";
	print STDERR "          Input expression files:\n";
	print STDERR "                 $file\n";
	print STDERR "                 $legacyFile\n";
	my $cmd = "rnaSeqCorrTwoExpts.R $file $legacyFile $outputFile";
	system($cmd);
	my ($numFailedCorrelations1,$correlations1) = makeReportFromOutputFile($outputFile);
	$datasetError=1 if ($numFailedCorrelations1);

	if ($fileTwo && $legacyFileTwo) {
	    my ($numFailedCorrelations2,$correlations2);
	    my ($numFailedCorrelations3,$correlations3);
	    my ($numFailedCorrelations4,$correlations4);

	    print STDERR "\n   Testing correlations of profile $newProfileName\n"; 
	    my $outputFile = "$orgDirectory/correlations_${studyIdTwo}.txt";
	    print STDERR "          File containing all correlations: $outputFile\n";
	    print STDERR "          Input expression files:\n";
	    print STDERR "                 $fileTwo\n";
	    print STDERR "                 $legacyFileTwo\n";
	    my $cmd = "rnaSeqCorrTwoExpts.R $fileTwo $legacyFileTwo $outputFile";
	    system($cmd);
	    ($numFailedCorrelations2,$correlations2) = makeReportFromOutputFile($outputFile);

	    print STDERR "\n   Testing correlations after switching strands:\n";
	    $outputFile = "$orgDirectory/correlations_${studyId}_A.txt"; 
	    print STDERR "          File containing all correlations: $outputFile\n";
	    print STDERR "          Input expression files:\n";
	    print STDERR "                 $fileTwo\n";
	    print STDERR "                 $legacyFile\n";
	    $cmd = "rnaSeqCorrTwoExpts.R $fileTwo $legacyFile $outputFile";
	    system($cmd);
	    ($numFailedCorrelations3,$correlations3) = makeReportFromOutputFile($outputFile);

	    print STDERR "\n   Testing correlations after switching strands (the other pair):\n";
	    $outputFile = "$orgDirectory/correlations_${studyId}_B.txt"; 
	    print STDERR "          File containing all correlations: $outputFile\n";
	    print STDERR "          Input expression files:\n";
	    print STDERR "                 $file\n";
	    print STDERR "                 $legacyFileTwo\n";
	    $cmd = "rnaSeqCorrTwoExpts.R $file $legacyFileTwo $outputFile";
	    system($cmd);
	    ($numFailedCorrelations4,$correlations4) = makeReportFromOutputFile($outputFile);

	    my @corrBefore = (@{$correlations1},@{$correlations2});
	    my $numCorrBefore = scalar @corrBefore;
	    my @corrAfter = (@{$correlations3},@{$correlations4});
	    my $numCorrAfter = scalar @corrAfter;
	    my $corrMeanBefore = sprintf("%.3f",mean(\@corrBefore));
	    my $corrMeanAfter = sprintf("%.3f",mean(\@corrAfter));
	    my $numFailedBeforeSwitch = $numFailedCorrelations1 + $numFailedCorrelations2;
	    my $numFailedAfterSwitch = $numFailedCorrelations3 + $numFailedCorrelations4;
	    $datasetError = 1 if ($numFailedBeforeSwitch > 0);

	    print STDERR "\n    RESULT: Average correlation $corrMeanBefore and $numFailedBeforeSwitch / $numCorrBefore correlations failed.\n";
	    print STDERR "            After switching strands, average correlation $corrMeanAfter and $numFailedAfterSwitch / $numCorrAfter correlations failed.\n";
	} else {
	    push @correlationsUnstranded, @{$correlations1};
	    $numCorrFailedUnstranded += $numFailedCorrelations1;   
	}

    }

    my $numCorrUnstranded = scalar @correlationsUnstranded;
    if ($numCorrUnstranded > 0) {
	$datasetError = 1 if ($numCorrFailedUnstranded > 0);
	my $corrMeanUnstranded = sprintf("%.3f",mean(\@correlationsUnstranded));
	print STDERR "\n    RESULT: Average correlation $corrMeanUnstranded and $numCorrFailedUnstranded / $numCorrUnstranded correlations failed.\n";
    }

    if ($datasetError) {
	print STDERR "\n    ---DATASET FAILED---\n";
	$numDatasetsWithError++;
    } else {
	print STDERR "\n    ---DATASET PASSED---\n";
    }
}

$dbh->disconnect();
if($legacyDatabaseInstance) {
  $legacyDbh->disconnect();
}

my $numLegacyDatasets=0;
if($legacyDatabaseInstance) {
    foreach my $dataset (keys %$legacyDbProfiles) {  
	if (! exists $dbProfiles->{$dataset}) {
	    print STDERR "ERROR:  Dataset $dataset is in the legacy database, but NOT in the new database.\n\n\
";
	    $numLegacyDatasets++;

	}
    }
}


print STDERR "\n\n================SUMMARY================\n";
print STDERR "Number of new datasets: $numDatasets\n";
print STDERR "Number of new datasets with errors: $numDatasetsWithError\n";

print STDERR "Number of legacy sites NOT in new database: $numLegacyDatasets\n";










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
  my ($file) = @_;

  my $numFailedTests=0;  
  my @correlations;

  open(FILE, $file) or die "Cannot open file $file for reading: $!";

  my $header = <FILE>;
  chomp $header;
  my @headers = split(/\t/, $header);
  my $lastIndex = scalar @headers - 1;
  my %indexToSample = map { $_ => $headers[$_] } 1..$lastIndex;

  while(<FILE>) {
    chomp;
    my @a = split(/\t/, $_);
    my $sampleName = $a[0]; 

    my $bestCorr;
    my $bestSample;
    my $selfCorr;
    for (my $i=1; $i<=$lastIndex; $i++) {
	if ($a[$i] eq "NA") {
	    next;
	} elsif ($a[$i] > $bestCorr) {
	    $bestCorr = $a[$i];
	    $bestSample=$indexToSample{$i};
	}
	if ($indexToSample{$i} eq $sampleName) {
	    $selfCorr = $a[$i];
	}
    }

    push @correlations, $selfCorr if ($selfCorr);

    my $threshold = 0.9;
    my $selfThreshold = 0.99;
    if (! $bestSample || ! $bestCorr ) {
	print STDERR "ERROR:  Could not calculate any correlation for sample '$sampleName'. The legacy or new data may not exist for this sample. Did the tuning manager finish?\n";
	$numFailedTests++;
    } elsif (! $selfCorr) {
	 print STDERR "ERROR: Could not find the paired sample for sample '$sampleName'. But this sample best correlated with sample '$bestSample' with a correlation of $bestCorr\n";
    } elsif ($selfCorr < $bestCorr) {
	if ($selfCorr > $selfThreshold) {
	    print STDERR "WARN:  Sample '$sampleName' did not correlate best with itself ($selfCorr) but it is still really high. It correlated better with '$bestSample' ($bestCorr)\n";
	} else {               
	    print STDERR "ERROR:  Sample '$sampleName' did not correlate best with itself ($selfCorr). It correlated better with '$bestSample' ($bestCorr)\n";
	    $numFailedTests++;
	}
    } elsif ($selfCorr < $threshold) {
	print STDERR "ERROR:  Sample '$sampleName' correlated best with itself ($selfCorr) but this correlation is below the threshold of $threshold.\n";
	$numFailedTests++;
    } else {
	print STDERR "          Ok: sample '$sampleName'\n";
    }
  }

  return ($numFailedTests,\@correlations);
}

sub combineFiles {
    my ($inputFiles,$outputFile) = @_;
    my $numFiles = scalar @{$inputFiles};
    die "There should only be two input files\n" if ($numFiles != 2);
    my $expression;
    my @samples;
    foreach my $file (@{$inputFiles}) {
	open(IN,$file) || die "Count not open $file for reading\n";
	my $header = <IN>;
	chomp $header;
	@samples = split("\t",$header);
	shift @samples;
	while (my $line = <IN>) {
	    chomp $line;
	    my @values = split("\t",$line);
	    my $gene = shift @values;
	    for (my $i=0; $i<(scalar @values); $i++) {
		if (exists $expression->{$gene}->{$samples[$i]}) {
		    $expression->{$gene}->{$samples[$i]} += $values[$i];
		} else {
		    $expression->{$gene}->{$samples[$i]} = $values[$i];
		}
	    }
	}
	close IN;
    }

    open(OUT,">",$outputFile) || die "Cannot open file $outputFile for writing\n";
    print OUT "Gene\t".join("\t",@samples)."\n";
    foreach my $gene (keys %{$expression}) {
	print OUT "$gene";
	foreach my $sample (@samples) {
	    print OUT "\t".$expression->{$gene}->{$sample};
	}
	print OUT "\n";
    }
    close OUT;
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


sub mean {
    my ($arrayRef) = @_;
    my $sum = 0;
    my $numSamples = scalar @{$arrayRef};
    foreach my $number (@{$arrayRef}) {
	$sum += $number;
    }
    return $sum/$numSamples;
}


1;
