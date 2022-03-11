#!/usr/bin/perl

use strict;
use DBI;
use IO::File;
use Getopt::Long;
use CBIL::Util::PropertySet;
use File::Basename;
use File::Copy;
use LWP::UserAgent;

my ($dbname, $gusConfigFile);
my $metadataFile = "CyverseMetadata.csv";
my $targetDirectory = "CyverseFiles";

&GetOptions('database|d=s' => \$dbname,
            'gusConfigFile|c=s' => \$gusConfigFile,
            'metadataFile|m=s' => \$metadataFile,
            'targetDirectory|t=s' => \$targetDirectory,
            );

die "usage: generateStatsByGenus -database|d <database> -gusConfigFile|c <configFile optional if in gus_home/config> -metadataFile|m <output file name for Cyverse metadata (default = CyverseMetadata.csv)>\n -targetDirectory|t <target directory to organize files (default = CyverseFiles>" unless $dbname;

if(!-d "$targetDirectory"){
  mkdir $targetDirectory or die "unable to create targetDirectory $targetDirectory\n";
}

#------- Uid and Password..these are fetched from the gus.cnfig file----------
$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config ($gusConfigFile) file not found! \n";
  exit;
}

my @mdFields = qw/FILENAME PROJECT_ID SOURCE_ID PUBLIC_ABBREV ORTHOMCL_ABBREV FAMILY_NAME_FOR_FILES ORGANISM_NAME GENOME_SOURCE STRAIN_ABBREV IS_ANNOTATED_GENOME IS_REFERENCE_STRAIN IS_FAMILY_REPRESENTATIVE NAME_FOR_FILENAMES COMPONENT_TAXON_ID DATABASE_VERSION MEGABPS NCBI_TAX_ID SNPCOUNT GENECOUNT PSEUDOGENECOUNT CODINGGENECOUNT OTHERGENECOUNT CHIPCHIPGENECOUNT ORTHOLOGCOUNT GOCOUNT TFBSCOUNT PROTEOMICSCOUNT ESTCOUNT ECNUMBERCOUNT ISORGANELLAR HASHTSISOLATE HASPOPSET HASEPITOPE HASARRAY HASCENTROMERE CONTIGCOUNT SUPERCONTIGCOUNT CHROMOSOMECOUNT COMMUNITYCOUNT POPSETCOUNT ARRAYGENECOUNT RNASEQCOUNT RTPCRCOUNT AVG_TRANSCRIPT_LENGTH SPECIES SPECIES_NCBI_TAX_ID STRAIN/;

open(M, ">$metadataFile") or die "unable to open $metadataFile for writing\n";

foreach my $md (@mdFields){
  print M "\"$md\"";
  print M $mdFields[-1] eq $md ? "\n" : ",";
}
##remove filename from mdfields
shift(@mdFields);

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);


my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect("dbi:Oracle:$dbname", $u, $pw) ||  die "Couldn't connect to database: " . DBI->errstr;

my $sql = "select * from apidbtuning.organismattributes where is_reference_strain = 1";

my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$sth->execute ||  die "Failed to  execute statement: " . $sth->errstr;


my %files;
my $B = new LWP::UserAgent (agent => 'Mozilla/5.0', cookie_jar =>{});
my $url = 'https://veupathdb.org/veupathdb/service/record-types/organism/searches/GenomeDataTypes/reports/attributesTabular?reportConfig={"attributes":["primary_key","URLGenomeFasta","URLproteinFasta","URLgff"],"includeHeader":true,"attachmentType":"plain"}';
my $get = $B->get($url)->content;
foreach my $l (split("\n",$get)){
  my @f = split("\t",$l);
  for(my $a = 1;$a<4;$a++){
    push(@{$files{$f[0]}},$f[$a]) if $a;
  }
}
print STDERR "Identified ",scalar(keys%files)," organisms to process\n";

my $ctFiles = 0;
while (my $row = $sth->fetchrow_hashref()) {
  my $org = $row->{ORGANISM_NAME};
  if($files{$org}){
    print STDERR "Processing $org\n";
    foreach my $a (@{$files{$org}}){
      next if $row->{IS_ANNOTATED_GENOME} eq  '0' && $a =~ /(AnnotatedProteins\.fasta|\.gff)/;
      &processFile($a,$row);
#      &writeMetadata($a,$row);
      $ctFiles++;
    }
  }else{
    print STDERR "ERROR: unable to find files for $org\n";
  }
}

print STDERR "Processed $ctFiles files\n";

close M;
$dbh->disconnect();


sub processFile {
  my($url,$md) = @_;
  #first directory structure
  my $comp = $md->{PROJECT_ID};
  if(!-d "$targetDirectory/$comp"){
    mkdir "$targetDirectory/$comp" or die "unable to create component directory $comp\n";
  }
  my $genus;
  if($md->{SPECIES} =~ /^\W*(\w+)/){
    $genus = $1;
  }
  die "unable to determine genus for $url\n" unless $genus;
  my $filePath = "$targetDirectory/$comp/$genus";
  if(!-d "$filePath"){
    mkdir "$filePath" or die "unable to create genus directory $comp/$genus\n";
  }
  my $fn;
  if($url =~ /^.*\/(.*)$/){
    $fn = $1;
    print STDERR "$fn\n";
  }else{
    print STDERR "ERROR: unable to parse filename from $url\n";
  }
  my $cmd = "wget --output-document=$filePath/$fn $url";
  system($cmd);

  &writeMetadata($fn,$md);
}

sub writeMetadata {
  my($fn,$md) = @_;
  print M "\"$fn\",";
  &printMDRow($md);
}

sub printMDRow {
  my $md = shift;
  foreach my $f (@mdFields){
    print M "\"$md->{$f}\"";
    print M $mdFields[-1] eq $f ? "\n" : ",";
  }
}
