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
	print STDERR "WARNING: There are more than 2 scaled profiles\n";
    }
    if (($numProfiles-$numScaled) > 2) {
	print STDERR "WARNING: There are more than 2 non-scaled profiles\n";
    }

    my $isStrandedInLegacyDb;
    if ( $legacyDatabaseInstance ) {
	if ( ! exists $legacyDbProfiles->{$dataset}) {
	    print STDERR "   WARNING:  Could not find a matching legacy dataset for dataset=$dataset\n";
	    print STDERR "\n    ---DATASET FAILED---\n";
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
		print STDERR "WARNING: There are more than 2 scaled profiles\n";
	    }
	    if (($numLegacyProfiles-$numLegacyScaled) > 2) {
		print STDERR "WARNING: There are more than 2 non-scaled profiles\n";
	    }
	  
	    foreach my $profile (keys %{$dbProfiles->{$dataset}}) {
		if (! exists $legacyDbProfiles->{$dataset}->{$profile} ) {
		    print STDERR "ERROR: The new profile $profile does not exist in the legacy database.\n";                    		    $datasetError=1;
		}
	    }
	    foreach my $profile (keys %{$legacyDbProfiles->{$dataset}}) {
		if (! exists $dbProfiles->{$dataset}->{$profile} ) {
		    print STDERR "ERROR: The legacy profile $profile does not exist in the new database.\n";                    		    $datasetError=1;
		}
	    }
	    
	    if($isStrandedInDb ne $isStrandedInLegacyDb) {
		print STDERR "WARNING:  Dataset $dataset is $isStrandedInDb in first instance but $isStrandedInLegacyDb in legacy db\n";
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
    my $numSampleCorrFailedUnstranded=0;
    my @sampleCorrelationsUnstranded;
    my $sampleCorrelations;
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
	    if (! exists $profiles->{legacy}->{$newProfileName}) {
		print STDERR "ERROR:   Skipping correlation because unable to find matching profile for $profileName. Tried $newProfileName but that did not work.\n";
		$datasetError=1;
		next;
	    }
	    my $firstStrandId = $profiles->{legacy}->{$newProfileName}->{id};
	    my $firstStrandFile = "$legacyOrgDirectory/${firstStrandId}.txt";
	    $newProfileName =~ s/firststrand/secondstrand/;
	    if (! exists $profiles->{legacy}->{$newProfileName}) {
		print STDERR "ERROR:   Skipping correlation because unable to find matching profile for $profileName. Tried $newProfileName but that did not work.\n";
		$datasetError=1;
		next;
	    }
	    my $secondStrandId = $profiles->{legacy}->{$newProfileName}->{id};
	    my $secondStrandFile = "$legacyOrgDirectory/${secondStrandId}.txt";
	    $legacyFile = $legacyOrgDirectory."/combined_".$firstStrandId."_".$secondStrandId.".txt";
	    my @fileNames = ($firstStrandFile,$secondStrandFile);
	    print STDERR "            Combining\n";
	    print STDERR "                $_\n" foreach (@fileNames);
	    print STDERR "            into this file: $legacyFile\n";
	    &combineFiles(\@fileNames,$legacyFile);
	} elsif ( $sumFiles eq "new" && $profileName =~ /firststrand/) {  # legacy is unstranded and new is stranded, only do this for secondstrand
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
	    if (! exists $profiles->{legacy}->{$newProfileName}) {
		print STDERR "ERROR:   Skipping correlation because unable to find matching profile for $profileName. Tried $newProfileName but that did not work.\n";
		$datasetError=1;
		next;
	    }
	    $legacyStudyId = $profiles->{legacy}->{$newProfileName}->{id};
	    $legacyFile = "$legacyOrgDirectory/${legacyStudyId}.txt";
	} elsif ( $sumFiles eq "new" && $profileName =~ /secondstrand/) {
	    next;
	} else {
	    print STDERR "ERROR:   Skipping correlations because unable to find matching profile for $profileName\n";
	    $datasetError=1;
	    next;
	}

	print STDERR "\n   Testing correlations of profile $profileName.\n"; 
	my $sampleOutputFile = "$orgDirectory/sample_correlations_${studyId}";
	my $geneOutputFile = "$orgDirectory/gene_correlations_${studyId}";
	print STDERR "          Files containing scatterplots and sample correlations: ${sampleOutputFile}.txt  ${sampleOutputFile}.pdf\n";
	print STDERR "          File containing gene correlations: ${geneOutputFile}.txt\n";
	print STDERR "          Input expression files:\n";
	print STDERR "                 $file\n";
	print STDERR "                 $legacyFile\n";
	my $cmd = "rnaSeqSampleCorrTwoExpts.R $file $legacyFile $sampleOutputFile";
	system($cmd);
	my ($numFailedSampleCorrelations1,$sampleCorrelations1) = &makeReportFromSampleOutputFile("${sampleOutputFile}.txt");
	if ($numFailedSampleCorrelations1 == -1) {
	    $datasetError = 1;
	    next;
	} elsif ($numFailedSampleCorrelations1 > 0) {
	    $datasetError = 1;
	}

	$cmd = "rnaSeqGeneCorrTwoExpts.R $file $legacyFile $geneOutputFile";
	system($cmd);
	&makeReportFromGeneOutputFile("${geneOutputFile}.txt");

	if ($fileTwo && $legacyFileTwo) {
	    my ($numFailedSampleCorrelations2,$sampleCorrelations2);
	    my ($numFailedSampleCorrelations3,$sampleCorrelations3);
	    my ($numFailedSampleCorrelations4,$sampleCorrelations4);

	    print STDERR "\n   Testing correlations of profile $newProfileName\n"; 
	    my $sampleOutputFile = "$orgDirectory/sample_correlations_${studyIdTwo}";
	    my $geneOutputFile = "$orgDirectory/gene_correlations_${studyIdTwo}";
	    print STDERR "          Files containing scatterplot and sample correlations: ${sampleOutputFile}.txt ${sampleOutputFile}.pdf\n";
	    print STDERR "          File containing gene correlations: ${geneOutputFile}.txt\n";
	    print STDERR "          Input expression files:\n";
	    print STDERR "                 $fileTwo\n";
	    print STDERR "                 $legacyFileTwo\n";
	    my $cmd = "rnaSeqSampleCorrTwoExpts.R $fileTwo $legacyFileTwo $sampleOutputFile";
	    system($cmd);
	    $cmd = "rnaSeqGeneCorrTwoExpts.R $fileTwo $legacyFileTwo $geneOutputFile";
	    system($cmd);

	    ($numFailedSampleCorrelations2,$sampleCorrelations2) = &makeReportFromSampleOutputFile("${sampleOutputFile}.txt");
	    &makeReportFromGeneOutputFile("${geneOutputFile}.txt");

	    print STDERR "\n   Testing correlations after switching strands:\n";
	    $sampleOutputFile = "$orgDirectory/sample_correlations_${studyId}_A"; 
	    $geneOutputFile = "$orgDirectory/gene_correlations_${studyId}_A"; 
	    print STDERR "          Files containing scatterplots and sample correlations: ${sampleOutputFile}.txt  ${sampleOutputFile}.pdf\n";
	    print STDERR "          File containing gene correlations: ${geneOutputFile}.txt\n";
	    print STDERR "          Input expression files:\n";
	    print STDERR "                 $fileTwo\n";
	    print STDERR "                 $legacyFile\n";
	    $cmd = "rnaSeqSampleCorrTwoExpts.R $fileTwo $legacyFile $sampleOutputFile";
	    system($cmd);
	    $cmd = "rnaSeqGeneCorrTwoExpts.R $fileTwo $legacyFile $geneOutputFile";
	    system($cmd);

	    ($numFailedSampleCorrelations3,$sampleCorrelations3) = &makeReportFromSampleOutputFile("${sampleOutputFile}.txt");
	    &makeReportFromGeneOutputFile("${geneOutputFile}.txt");

	    print STDERR "\n   Testing correlations after switching strands (the other pair):\n";
	    $sampleOutputFile = "$orgDirectory/sample_correlations_${studyId}_B"; 
	    $geneOutputFile = "$orgDirectory/gene_correlations_${studyId}_B"; 
	    print STDERR "          Files containing scatterplots and sample correlations: ${sampleOutputFile}.txt ${sampleOutputFile}.pdf\n";
	    print STDERR "          File containing gene correlations: ${geneOutputFile}.txt\n";
	    print STDERR "          Input expression files:\n";
	    print STDERR "                 $file\n";
	    print STDERR "                 $legacyFileTwo\n";
	    $cmd = "rnaSeqSampleCorrTwoExpts.R $file $legacyFileTwo $sampleOutputFile";
	    system($cmd);
	    $cmd = "rnaSeqGeneCorrTwoExpts.R $file $legacyFileTwo $geneOutputFile";
	    system($cmd);

	    ($numFailedSampleCorrelations4,$sampleCorrelations4) = &makeReportFromSampleOutputFile("${sampleOutputFile}.txt");
	    &makeReportFromGeneOutputFile("${geneOutputFile}.txt");

	    my @corrBefore = (@{$sampleCorrelations1},@{$sampleCorrelations2});
	    my $numCorrBefore = scalar @corrBefore;
	    my @corrAfter = (@{$sampleCorrelations3},@{$sampleCorrelations4});
	    my $numCorrAfter = scalar @corrAfter;
	    my $corrMeanBefore = sprintf("%.3f",mean(\@corrBefore));
	    my $corrMeanAfter = sprintf("%.3f",mean(\@corrAfter));
	    my $numFailedBeforeSwitch = $numFailedSampleCorrelations1 + $numFailedSampleCorrelations2;
	    my $numFailedAfterSwitch = $numFailedSampleCorrelations3 + $numFailedSampleCorrelations4;
	    $datasetError = 1 if ($numFailedBeforeSwitch > 0);

	    print STDERR "\n    RESULT: Average between-sample correlation $corrMeanBefore and $numFailedBeforeSwitch / $numCorrBefore correlations failed.\n";
	    print STDERR "            After switching strands, average correlation $corrMeanAfter and $numFailedAfterSwitch / $numCorrAfter correlations failed.\n";
	    if ($corrMeanAfter > $corrMeanBefore) {
		print STDERR "            The correlation is higher after switching strands. For the new build, it is likely that you need to\n";
		print STDERR "               flip the values for switchStrandsGBrowse and switchStrandsProfiles properties in the dataset\n";
		print STDERR "               presenter xml. To be sure, check whether you see the expected coverage in JBrowse tracks and\n";
		print STDERR "               expected FPKM/TPM values on the gene page.\n";
	    } else {
		print STDERR "            The correlation is NOT higher after switching strands. For the new build, it is likely that you DO NOT\n";
		print STDERR "               need to switch the values for switchStrandsGBrowse and switchStrandsProfiles properties in the\n";
		print STDERR "               dataset presenter xml. To be sure, check whether you see the expected coverage in JBrowse tracks\n";
		print STDERR "               and expected FPKM/TPM values on the gene page.\n";
	    }
	} else {
	    push @sampleCorrelationsUnstranded, @{$sampleCorrelations1};
	    $numSampleCorrFailedUnstranded += $numFailedSampleCorrelations1;   
	}

    }

    my $numSampleCorrUnstranded = scalar @sampleCorrelationsUnstranded;
    if ($numSampleCorrUnstranded > 0) {
	$datasetError = 1 if ($numSampleCorrFailedUnstranded > 0);
	my $sampleCorrMeanUnstranded = sprintf("%.3f",mean(\@sampleCorrelationsUnstranded));
	print STDERR "\n    RESULT: Average between-sample correlation $sampleCorrMeanUnstranded and $numSampleCorrFailedUnstranded / $numSampleCorrUnstranded correlations failed.\n";
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

print STDERR "\nMaking sure all legacy datasets are in the new database\n";
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
from apidbtuning.profile  p, webready.GeneAttributes_p ga
where p.profile_study_id = $studyId 
and profile_type = 'values' 
and ga.source_id = p.source_id (+)
order by ga.source_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($sourceId,$profile) = $sh->fetchrow_array()) {
#      if ($sourceId =~ /^(\S+)\.(\S+)$/) {      # Use this when gene ID has a version in one but not other
#	  $sourceId = $1;                        # for example, ENSG00000001.2
#      }
      print $fh "$sourceId\t$profile\n";
  }
}


sub makeReportFromGeneOutputFile {
  my ($file) = @_;

  my $geneCorrelation;
  my $geneExpression;

  open(FILE, $file) or die "Cannot open file $file for reading: $!";

  my $header = <FILE>;
  chomp $header;
  if ($header =~ /unmatched samples/ || $header =~ /only one sample/) {
      print STDERR "\n     =========GENE CORRELATIONS=========\n";
      print STDERR "         cannot be calculated because $header\n";
      close FILE;
      return 0;
  }

  my $numGenes = 0;
  my $numVariableGenes = 0;
  while (my $line =<FILE>) {
      chomp $line;
      my @row = split("\t",$line);
      my $gene = $row[0];
      my $expression = $row[1];
      my $corr = $row[2];
      my $maxFc = $row[3];
      $numGenes++;
      next if ($maxFc < 2);
      $numVariableGenes++;
      $geneCorrelation->{$gene} = $corr;
      $geneExpression->{$gene} = $expression;
  }
  close FILE;

  my @correlations = values %{$geneCorrelation};
  my ($meanCorr,$sdCorr) = meanSd(\@correlations);
  my @expression = values %{$geneExpression};
  my ($meanExpr,$sdExpr) = meanSd(\@expression);
  $meanCorr = sprintf("%.3f",$meanCorr);
  $sdCorr = sprintf("%.3f",$sdCorr);

  my $lowExprGoodCorr;
  my $lowExprPoorCorr;
  my $lowExprNegativeCorr;
  my $midExprGoodCorr;
  my $midExprPoorCorr;
  my $midExprNegativeCorr;
  my $highExprGoodCorr;
  my $highExprPoorCorr;
  my $highExprNegativeCorr;

  my $corrCutoff = 0.5;
  my $exprCutoff = 0.5;
  my $corrCutoffFormatted = sprintf("%.2f",$corrCutoff);

  foreach my $gene (keys %{$geneExpression}) {
      if ($geneExpression->{$gene} < ($meanExpr * $exprCutoff)) {
	  if ($geneCorrelation->{$gene} > $corrCutoff) {
	      $lowExprGoodCorr->{$gene} = $geneCorrelation->{$gene};
	  } elsif ($geneCorrelation->{$gene} <= $corrCutoff && $geneCorrelation->{$gene} > -$corrCutoff) {
	      $lowExprPoorCorr->{$gene} = $geneCorrelation->{$gene};
	  } else {
	      $lowExprNegativeCorr->{$gene} = $geneCorrelation->{$gene};
	  }
      } elsif ($geneExpression->{$gene} >= ($meanExpr * $exprCutoff) && $geneExpression->{$gene} < ($meanExpr / $exprCutoff)) { 
	  if ($geneCorrelation->{$gene} > $corrCutoff) {
	      $midExprGoodCorr->{$gene} = $geneCorrelation->{$gene};
	  } elsif ($geneCorrelation->{$gene} <= $corrCutoff && $geneCorrelation->{$gene} > -$corrCutoff) {
	      $midExprPoorCorr->{$gene} = $geneCorrelation->{$gene};
	  } else {
	      $midExprNegativeCorr->{$gene} = $geneCorrelation->{$gene};
	  }
      } else {
	  if ($geneCorrelation->{$gene} > $corrCutoff) {
	      $highExprGoodCorr->{$gene} = $geneCorrelation->{$gene};
	  } elsif ($geneCorrelation->{$gene} <= $corrCutoff && $geneCorrelation->{$gene} > -$corrCutoff) {
	      $highExprPoorCorr->{$gene} = $geneCorrelation->{$gene};
	  } else {
	      $highExprNegativeCorr->{$gene} = $geneCorrelation->{$gene};
	  }
      }
  }

  my $numLoExpGoodCorr = keys %{$lowExprGoodCorr};
  my $numLoExpPoorCorr = keys %{$lowExprPoorCorr};
  my $numLoExpNegCorr = keys %{$lowExprNegativeCorr};
  my $numMidExpGoodCorr = keys %{$midExprGoodCorr};
  my $numMidExpPoorCorr = keys %{$midExprPoorCorr};
  my $numMidExpNegCorr = keys %{$midExprNegativeCorr};
  my $numHiExpGoodCorr = keys %{$highExprGoodCorr};
  my $numHiExpPoorCorr = keys %{$highExprPoorCorr};
  my $numHiExpNegCorr = keys %{$highExprNegativeCorr};

  print STDERR "\n      =========SINGLE GENE CORRELATIONS (ACROSS SAMPLES)========\n";
  print STDERR "        $numVariableGenes / $numGenes exhibit >2-fold change and will be evaluated.\n";
  print STDERR "        Distribution (num of genes):\n";
  print STDERR "            low=low expression (below $exprCutoff * mean),mid=middle expression (between $exprCutoff * mean and mean / $exprCutoff), high=high expression (above mean / $exprCutoff)\n";
  print STDERR "            good: r >= $corrCutoffFormatted, poor: -$corrCutoffFormatted <= r < $corrCutoffFormatted, negative: r < -$corrCutoffFormatted\n";
  print STDERR "        \tgood\tpoor\tnegative\n";
  print STDERR "        low\t$numLoExpGoodCorr\t$numLoExpPoorCorr\t$numLoExpNegCorr\n";
  print STDERR "        mid\t$numMidExpGoodCorr\t$numMidExpPoorCorr\t$numMidExpNegCorr\n";
  print STDERR "        high\t$numHiExpGoodCorr\t$numHiExpPoorCorr\t$numHiExpNegCorr\n";

  my $numGenesToShow=3;

  print STDERR "         Here are the top $numGenesToShow genes from each category:\n";

  print STDERR "             Low expression, good correlation:\n";
  my $i = $numGenesToShow;
  foreach my $gene (sort { $lowExprGoodCorr->{$b} <=> $lowExprGoodCorr->{$a} } keys %{$lowExprGoodCorr}) {
      my $geneCorr = sprintf("%.3f",$lowExprGoodCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             Low expression, poor correlation:\n";
  $i = $numGenesToShow;
  my %poorCorr = map { $_ => abs($lowExprPoorCorr->{$_}) } keys %{$lowExprPoorCorr};
  foreach my $gene (sort { $poorCorr{$a} <=> $poorCorr{$b} } keys %poorCorr) {
      my $geneCorr = sprintf("%.3f",$lowExprPoorCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             Low expression, negative correlation:\n";
  $i = $numGenesToShow;
  foreach my $gene (sort { $lowExprNegativeCorr->{$a} <=> $lowExprNegativeCorr->{$a} } keys %{$lowExprNegativeCorr}) {
      my $geneCorr = sprintf("%.3f",$lowExprNegativeCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             Mid expression, good correlation:\n";
  $i = $numGenesToShow;
  foreach my $gene (sort { $midExprGoodCorr->{$b} <=> $midExprGoodCorr->{$a} } keys %{$midExprGoodCorr}) {
      my $geneCorr = sprintf("%.3f",$midExprGoodCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             Mid expression, poor correlation:\n";
  $i = $numGenesToShow;
  %poorCorr = map { $_ => abs($midExprPoorCorr->{$_}) } keys %{$midExprPoorCorr};
  foreach my $gene (sort { $poorCorr{$a} <=> $poorCorr{$b} } keys %poorCorr) {
      my $geneCorr = sprintf("%.3f",$midExprPoorCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             Mid expression, negative correlation:\n";
  $i = $numGenesToShow;
  foreach my $gene (sort { $midExprNegativeCorr->{$a} <=> $midExprNegativeCorr->{$a} } keys %{$midExprNegativeCorr}) {
      my $geneCorr = sprintf("%.3f",$midExprNegativeCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             High expression, good correlation:\n";
  $i = $numGenesToShow;
  foreach my $gene (sort { $highExprGoodCorr->{$b} <=> $highExprGoodCorr->{$a} } keys %{$highExprGoodCorr}) {
      my $geneCorr = sprintf("%.3f",$highExprGoodCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             High expression, poor correlation:\n";
  $i = $numGenesToShow;
  %poorCorr = map { $_ => abs($highExprPoorCorr->{$_}) } keys %{$highExprPoorCorr};
  foreach my $gene (sort { $poorCorr{$a} <=> $poorCorr{$b} } keys %poorCorr) {
      my $geneCorr = sprintf("%.3f",$highExprPoorCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }
  print STDERR "             High expression, negative correlation:\n";
  my $i = $numGenesToShow;
  foreach my $gene (sort { $highExprNegativeCorr->{$a} <=> $highExprNegativeCorr->{$a} } keys %{$highExprNegativeCorr}) {
      my $geneCorr = sprintf("%.3f",$highExprNegativeCorr->{$gene});
      print STDERR "               $gene correlation: $geneCorr \n";
      last if ($i < 1);
      $i--;
  }

  print STDERR "      =========================================================\n";
}

sub meanSd {
    my ($arrayRef) = @_;
    my $sum = 0;
    my $numSamples = scalar @{$arrayRef};
    foreach my $number (@{$arrayRef}) {
        $sum += $number;
    }
    my $mean = $sum/$numSamples;

    $sum=0;
    foreach my $number (@{$arrayRef}) {
        $sum += ($number-$mean)**2;
    }
    my $sd = sqrt($sum/$numSamples);

    return ($mean,$sd);
}


sub makeReportFromSampleOutputFile {
  my ($file) = @_;

  my $numFailedTests=0;  
  my @correlations;
  my $threshold = 0.9;
  my $selfThreshold = 0.99;

  open(FILE, $file) or die "Cannot open file $file for reading: $!";

  my $header = <FILE>;
  chomp $header;

  my @headers = split(/\t/, $header);
  my $lastIndex = scalar @headers - 1;
  my %indexToSample = map { $_ => $headers[$_] } 1..$lastIndex;

  while(my $line = <FILE>) {
    chomp($line);
    my @a = split(/\t/, $line);
    my $sampleName = $a[0];

    if ($sampleName eq "NumGenes_Min_Max") {
	my ($numGenes,$min,$max) = split("_",$a[1]);
	if ($numGenes == 0 || $min == 100000 || $max == 0) {
	    print STDERR "      ERROR: Only $numGenes genes match between databases. Can't calculate correlations.\n";
	    return (-1,\@correlations);
	} else {
	    print STDERR "      $numGenes genes ranged in expression from $min to $max.\n";
	    next;
	}
    }

    my $bestCorr;
    my $bestSample;
    my $selfCorr;
    my $fewGenesFlag;
    for (my $i=1; $i<=$lastIndex; $i++) {
	if ($a[$i] eq "NA") {
	    next;
	} elsif ($a[$i] == 10) {
	    $fewGenesFlag = 1;
	} elsif ($a[$i] > $bestCorr) {
	    $bestCorr = $a[$i];
	    $bestSample=$indexToSample{$i};
	}
	if ($indexToSample{$i} eq $sampleName) {
	    $selfCorr = $a[$i];
	}
    }

    push @correlations, $selfCorr if ($selfCorr);

    if (! $bestSample || ! $bestCorr ) {
	print STDERR "ERROR:  Could not calculate any correlation for sample '$sampleName'.\n";
	if ($fewGenesFlag) {
	    print STDERR "            The gene names seem to be different between databases.\n";
	} else { 
	    print STDERR "            The legacy or new data may not exist for this sample. Did the tuning manager finish?\n";
	}
	$numFailedTests++;
    } elsif (! $selfCorr) {
	$bestCorr = sprintf("%.3f",$bestCorr);
	print STDERR "ERROR: Could not find the paired sample for sample '$sampleName'. But this sample best correlated with sample '$bestSample' with a correlation of $bestCorr\n";
    } elsif ($selfCorr < $bestCorr) {
	if ($selfCorr > $selfThreshold) {
	    $bestCorr = sprintf("%.3f",$bestCorr);
	    $selfCorr = sprintf("%.3f",$selfCorr);
	    print STDERR "WARNING:  Sample '$sampleName' did not correlate best with itself ($selfCorr) but it is still really high. It correlated better with '$bestSample' ($bestCorr)\n";
	} else {               
	    $bestCorr = sprintf("%.3f",$bestCorr);
	    $selfCorr = sprintf("%.3f",$selfCorr);
	    print STDERR "ERROR:  Sample '$sampleName' did not correlate best with itself ($selfCorr). It correlated better with '$bestSample' ($bestCorr)\n";
	    $numFailedTests++;
	}
    } elsif ($selfCorr < $threshold) {
	$selfCorr = sprintf("%.3f",$selfCorr);
	print STDERR "ERROR:  Sample '$sampleName' correlated best with itself ($selfCorr) but this correlation is below the threshold of $threshold.\n";
	$numFailedTests++;
    } else {
	print STDERR "          Ok: sample '$sampleName'\n";
    }
  }
  close FILE;
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
    $profileSet =~ s/,//g;   # we have taken commas out of profile names

#    $dataset =~ s/mmul17573/mmulAG07107/;
#    $profileSet =~ s/Transcriptomes of 46 malaria-infected Gambian children/Transcriptome analysis of blood from Gambian children with malaria./;

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
