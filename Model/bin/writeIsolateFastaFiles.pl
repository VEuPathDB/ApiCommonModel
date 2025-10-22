#!/usr/bin/perl

use strict;

use DBI;
use DBD::Oracle;

use Getopt::Long;

use CBIL::Util::V;

use Data::Dumper;

my ($help, $databaseInstance, $organism, $workingDir);

&GetOptions('help|h' => \$help,
            'database_instance=s' => \$databaseInstance,
            'organism=s' => \$organism,
            'working_dir=s' => \$workingDir,
            );

my $dbh = &connectToDb($databaseInstance);
my $genes = &queryForGenes($dbh,$organism);
my $strains = &queryForStrains($dbh,$organism);

foreach my $strain (keys %{$strains}) {
    my $fileName = "$strain.fasta";
    $fileName =~ s/ /_/g;
    $fileName = "$workingDir/$fileName";
    next if (-e $fileName);
    open(OUT,">",$fileName) || die "Cannot open $strains.fasta for writing";
    $strain = "" if ($strain eq $organism);
    foreach my $seqId (sort keys %{$genes}) {
	my $strainSeqId = $seqId;
	$strainSeqId .= ".$strain" if ($strain ne "");

	my $seqRef = getEntireChromSeqFromDatabase($dbh,$strainSeqId);
	next if (${$seqRef} eq "");

	foreach my $gene (sort keys %{$genes->{$seqId}}) {
	    my $geneSeq = getSubSeqFromChrom($dbh,$seqRef,$genes->{$seqId}->{$gene}->{start},$genes->{$seqId}->{$gene}->{end});
	    $geneSeq = reverseComplement($geneSeq) if ($genes->{$seqId}->{$gene}->{strand} eq "reverse");
	    print OUT ">$gene\n$geneSeq\n\n";
	}
    }
    close OUT;
}

$dbh->disconnect();
exit;



sub makeDirectoryUnlessExists {
  my ($dir) = @_;
  mkdir $dir unless(-d $dir);
}


sub queryForGenes {
  my ($dbh,$organism) = @_;

  my $genes;

  my $sql = "
SELECT gene_source_id, sequence_id, gene_start_min, gene_end_max, strand
FROM webready.TranscriptAttributes_p
WHERE organism = '$organism'";
  
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($geneId, $seqId, $start, $end, $strand) = $sh->fetchrow_array()) {
      $genes->{$seqId}->{$geneId}->{start} = $start;
      $genes->{$seqId}->{$geneId}->{end} = $end;
      $genes->{$seqId}->{$geneId}->{strand} = $strand;
  }

  return $genes;
}

sub queryForStrains {
  my ($dbh,$organism) = @_;

  my $strains;

  my $sql = "
SELECT REPLACE(pan_name,' (Sequence Variation)','') pan_name
FROM apidbtuning.metadata
WHERE dataset_subtype = 'HTS_SNP'
AND organism = '$organism'
AND property = 'Parasite strain'";
  
  my $sh = $dbh->prepare($sql);
  $sh->execute();

  while(my ($strain) = $sh->fetchrow_array()) {
      $strains->{$strain} = 1;
  }
  $strains->{$organism} = 1;

  return $strains;
}

sub getEntireChromSeqFromDatabase {
    my ($dbh,$seqId) = @_;

    my $sequence="";

    my $sql = "
SELECT sequence
FROM dots.nasequence
WHERE source_id = '$seqId'";

    my $sh = $dbh->prepare($sql);
    $sh->execute();
    my $numSeqs = 0;
    while(my ($seq) = $sh->fetchrow_array()) {
	$sequence = $seq;
	$numSeqs++;
    }
    print "WARNING: There is no sequence for chromosome/contig $seqId\n" if ($numSeqs == 0);
    die "There are multiple sequences for chromosome/contig $seqId\n" if ($numSeqs > 1); 
    return \$sequence;
}

sub getSubSeqFromChrom {
  my ($dbh,$sequenceRef,$start,$end) = @_;
  return substr(${$sequenceRef},$start-1,$end-$start+1);
}

sub reverseComplement {
  my ($sequence) = @_;

  $sequence = reverse $sequence;
  $sequence =~ tr/ACGTacgt/TGCAtgca/;

  return $sequence;
}


sub connectToDb {
  my ($instance) = @_;

  my $dbiDsn = 'dbi:Oracle:' . $instance;
  my $dbh = DBI->connect($dbiDsn) or die DBI->errstr;
  $dbh->{RaiseError} = 1;
  $dbh->{AutoCommit} = 0;
  $dbh->{LongReadLen} = 10000000;

  return $dbh
}


1;
