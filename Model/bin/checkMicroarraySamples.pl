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
my $dbProfiles = &queryForProfiles($dbh);

my ($legacyDbh, $legacyDbProfiles);
if($legacyDatabaseInstance) {
  &makeDirectoryUnlessExists($legacyDatabaseDirectory);
  $legacyDbh = &connectToDb($legacyDatabaseInstance);
  $legacyDbProfiles = &queryForProfiles($legacyDbh);
}

my $numDatasets=0;
my $numDatasetsWithError=0;
foreach my $dataset (keys %$dbProfiles) {

    $numDatasets++;
    my $datasetError;

    print STDERR "\n\n****** Reporting on DATASET '$dataset' ******\n";
    my $numProfiles = scalar keys %{$dbProfiles->{$dataset}};
    if ($numProfiles == 0) {
	print STDERR "ERROR: Could not find any profiles for this dataset.\n";
	$datasetError=1;
    }

    my $profiles; # $profiles -> legacy/new -> profileName -> id 
    foreach my $profile (keys %{$dbProfiles->{$dataset}}) {
	print STDERR "          $profile\n";
	$profiles->{new}->{$profile}->{id} = $dbProfiles->{$dataset}->{$profile};
    }
    
    if ( $legacyDatabaseInstance ) {
	if ( ! exists $legacyDbProfiles->{$dataset}) {
	    print STDERR "   WARN:  Could not find a matching legacy dataset for dataset=$dataset\n";
	    print STDERR "\n    ---DATASET FAILED---\n";
	    $numDatasetsWithError++;
	    next;
	} else {
	    print STDERR "   Found a matching legacy dataset.\n";
	    my $numLegacyProfiles = scalar keys %{$legacyDbProfiles->{$dataset}};
	    if ($numLegacyProfiles == 0) {
		print STDERR "ERROR: Could not find any profiles for this dataset.\n";
		$datasetError=1;
	    }

	    foreach my $profile (keys %{$legacyDbProfiles->{$dataset}}) {
		print STDERR "          $profile\n";
		$profiles->{legacy}->{$profile}->{id} = $legacyDbProfiles->{$dataset}->{$profile};
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
	    my $numSamples = printHeader($studyId, $fh, $dbh);
	    &printData($studyId, $numSamples, $fh, $dbh);
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
		my $numSamples = printHeader($studyId, $fh, $legacyDbh);
		&printData($studyId, $numSamples, $fh, $legacyDbh);
		close $fh;
	    }
	}
    }

    my @sampleCorrelationsForThisDataset;
    my $numFailedSampleCorrelationsForThisDataset = 0;
    foreach my $profileName (keys %{$profiles->{new}}) {
	my $studyId = $profiles->{new}->{$profileName}->{id};
	my $file = "$orgDirectory/${studyId}.txt";
	my $legacyStudyId;
	my $legacyFile;
	
	if (exists $profiles->{legacy}->{$profileName}) {
	    $legacyStudyId = $profiles->{legacy}->{$profileName}->{id};
	    $legacyFile = "$legacyOrgDirectory/${legacyStudyId}.txt";
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
	$cmd = "rnaSeqGeneCorrTwoExpts.R $file $legacyFile $geneOutputFile";
	system($cmd);

	my ($numFailedSampleCorrelations,$sampleCorrelations) = makeReportFromSampleOutputFile("${sampleOutputFile}.txt");
	$datasetError=1 if ($numFailedSampleCorrelations);
	&makeReportFromGeneOutputFile("${geneOutputFile}.txt");

	push @sampleCorrelationsForThisDataset, @{$sampleCorrelations};
	$numFailedSampleCorrelationsForThisDataset += $numFailedSampleCorrelations;
    }

    my $numSampleCorr = scalar @sampleCorrelationsForThisDataset;

    if (! $numSampleCorr) {
	print STDERR "ERROR:   There were no correlations calculated for this dataset. Maybe missing sample(s) in legacy or new database?\n";
	$datasetError = 1;
    } else {
	$datasetError = 1 if ($numFailedSampleCorrelationsForThisDataset);
	my $sampleCorrMean = sprintf("%.3f",mean(\@sampleCorrelationsForThisDataset));
	print STDERR "\n    RESULT: Average between-sample correlation $sampleCorrMean and $numFailedSampleCorrelationsForThisDataset / $numSampleCorr correlations failed.\n";
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
  my ($studyId, $numSamples, $fh, $dbh) = @_;

  my $sql = "select ga.source_id, p.profile_as_string 
from apidbtuning.profile  p, webready.GeneAttributes_p ga
where p.profile_study_id = $studyId 
and profile_type = 'values' 
and ga.source_id = p.source_id (+)
order by ga.source_id";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($sourceId,$values) = $sh->fetchrow_array()) {
      my @logValues = split("\t",$values);
      next if (scalar @logValues != $numSamples);
      my @linearValues = map { 2**$_ } @logValues;
      print $fh $sourceId . "\t" . join("\t", @linearValues) . "\n";
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
      print STDERR "\n      =========SINGLE GENE CORRELATIONS (ACROSS SAMPLES)========\n";
      print STDERR "             Cannot be calculated because $header\n";
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

  my $numCorr = keys %{$geneCorrelation};
  my $numExpr = keys %{$geneExpression};
  if ($numCorr == 0 || $numExpr == 0) {
      print STDERR "\n      =========SINGLE GENE CORRELATIONS (ACROSS SAMPLES)========\n";
      print STDERR "             Cannot be calculated, likely because there are no genes that change more than 2-fold.\n";
      return;
  }

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
    if ($sampleName eq "NumGenes_Min_Max") {
	my ($numGenes,$min,$max) = split("_",$a[1]);
	print STDERR "      $numGenes genes ranged in expression from $min to $max.\n";
	next;
    }
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
	$bestCorr = sprintf("%.3f",$bestCorr);
	print STDERR "ERROR: Could not find the paired sample for sample '$sampleName'. But this sample best correlated with sample '$bestSample' with a correlation of $bestCorr\n";
    } elsif ($selfCorr < $bestCorr) {
	if ($selfCorr > $selfThreshold) {
	    $bestCorr = sprintf("%.3f",$bestCorr);
	    $selfCorr = sprintf("%.3f",$selfCorr);
	    print STDERR "WARN:  Sample '$sampleName' did not correlate best with itself ($selfCorr) but it is still really high. It correlated better with '$bestSample' ($bestCorr)\n";
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

  my $numSamples = scalar @a;
  return $numSamples;
}


sub makeDirectoryUnlessExists {
  my ($dir) = @_;

  mkdir $dir unless(-d $dir);

}


sub queryForProfiles {
  my ($dbh) = @_;

  my %rv;

  my $sql = "
SELECT dataset_name, profile_set_name, profile_study_id
FROM apidbtuning.profiletype 
WHERE dataset_type = 'transcript_expression' 
      AND dataset_subtype = 'array' 
      AND profile_type = 'values'
";

  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($dataset, $profileSet, $studyId) = $sh->fetchrow_array()) {
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
