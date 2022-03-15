#!/usr/bin/perl

use strict;
use DBI;
use IO::File;
use Getopt::Long;
use CBIL::Util::PropertySet;
#use File::Basename;
#use File::Copy;
use LWP::UserAgent;

my $gusConfigFile;
my $targetDirectory = "VEuPathDB";
my $metadataFile = "";
my $build = 'All';
my $debug = 0;

&GetOptions('gusConfigFile|c=s' => \$gusConfigFile,
            'metadataFile|m=s' => \$metadataFile,
            'targetDirectory|t=s' => \$targetDirectory,
            'build|b=s' => \$build,
            );

my $usage = "usage: makeCyverseFilesAndMetadata.pl -build <build number to process (eg 55)> -gusConfigFile|c <configFile optional if in gus_home/config> -metadataFile|m <output file name for Cyverse metadata (default = CyverseMetadata.csv)> -targetDirectory|t <target directory to organize files (default = CyverseFiles>\n";

die "ERROR: invalid build number: $build\n  $usage" unless $build eq "All" || $build =~ /^\d+$/;

if(!-d "$targetDirectory"){
  mkdir $targetDirectory or die "unable to create targetDirectory $targetDirectory\n";
}

#------- Uid and Password..these are fetched from the gus.cnfig file----------
$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config ($gusConfigFile) file not found! \n";
  exit;
}

# write metadatafile into target directory unless passed in on commandline
# include build in number in metadata filename
$metadataFile = $metadataFile ? $metadataFile : "$targetDirectory/CyverseMetadata$build.csv";
open(M, ">$metadataFile") or die "unable to open $metadataFile for writing\n";

my $ct = 0;

if($debug){ open(FD, ">files_debug.csv"); open(MD, ">md_debug.csv"); }

##first get the urls for generating the files
my %files;
my $ctRows = 0;
my $B = new LWP::UserAgent (agent => 'Mozilla/5.0', cookie_jar =>{});
my $url = 'https://veupathdb.org/veupathdb/service/record-types/organism/searches/GenomeDataTypes/reports/attributesTabular?reportConfig={"attributes":["primary_key","build_latest_update","is_annotated_genome","URLGenomeFasta","URLproteinFasta","URLgff"],"includeHeader":true,"attachmentType":"plain"}';
my $get = $B->get($url)->content;
foreach my $l (split("\n",$get)){
  my @f = split("\t",$l);
  $ctRows++;
  next unless $build eq "All" || $build == $f[1];  ##restrict to build number.  if no build arg on cmdline then get all
  print FD join('","',@f),"\n" if $debug;
  for(my $a = 3;$a<6;$a++){
    ##don't include files that don't exist for non-annotated genomes
    push(@{$files{$f[0]}},$f[$a]) unless $f[2] == 0 && $f[$a] =~ /(AnnotatedProteins\.fasta|\.gff)/;
  }
}
if(scalar(keys%files) == 0){
  die "ERROR: invalid build number: retrieved $ctRows rows from service call but 0 matched build $build\n  $usage";
}else{
  print STDERR "Identified ",scalar(keys%files)," genomes to process\n";
  if($debug){
    print STDERR "will process:\n";
    foreach my $k (keys%files){
      print STDERR "  $files{$k}->[0]: |$files{$k}->[1]|\n";
    }
  }
}

##next get the metadata using a service call
my $mds = new LWP::UserAgent (agent => 'Mozilla/5.0', cookie_jar =>{});
my $mdurl = 'https://veupathdb.org/veupathdb/service/record-types/organism/searches/GenomeDataTypes/reports/attributesTabular?reportConfig={"attributes":["primary_key","species","strain","project_id","contigCount","supercontigCount","chromosomeCount","is_annotated_genome","ncbi_tax_id","genome_version","annotation_version","annotation_source"],"includeHeader":true,"attachmentType":"plain"}';
my @tmpData = split("\n",$mds->get($mdurl)->content);
my @mdFields = split("\t",shift(@tmpData));
&writeMetadata("filename",\@mdFields);
my $ctFiles = 0;
foreach my $l (@tmpData){
  my @tmp = split("\t",$l);
  next unless $files{$tmp[0]};  ##skip unless included in build number
  print MD join('","',@tmp),"\n" if $debug;
  foreach my $a (@{$files{$tmp[0]}}){
    my @ptmp = @tmp;
    &processFile($a,\@ptmp);
    $ctFiles++;
  }
}
if($debug){ close MD; close FD; }

print STDERR "Processed $ctFiles files\n";

close M;

sub processFile {
  my($url,$md) = @_;
  #first directory structure
  my $comp = $md->[3]; ##4th element in array is project_id
  if(!-d "$targetDirectory/$comp"){
    mkdir "$targetDirectory/$comp" or die "unable to create component directory $comp\n";
  }
  my $genus;
  if($md->[0] =~ /^\W*(\w+)/){
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
    print die "ERROR: unable to parse filename from $url\n";
  }
  my $cmd = "wget --output-document=$filePath/$fn $url";
  system($cmd);

  &writeMetadata("$comp/$genus/$fn",$md);
}

sub writeMetadata {
  my($fn,$md) = @_;
  print M "\"$fn\",";
  &printMDRow($md);
}

sub printMDRow {
  my $md = shift;
  my $org = shift(@{$md});
  print M "\"$org\",";
  my $species = shift(@{$md});
  if($species eq "Species"){  ##header row
    print M "\"Genus\",\"Species\",";
  }elsif($species =~ /^(\S+)\s?(\S+)/){  ##parse out genus and species to separate
    print M "\"$1\",\"$2\",";
  }else{
    die "unable to parse genus and species out of $species\n";
  } 
  my $ct = 0;
  foreach my $f (@{$md}){
    print M "\"$f\"";
    print M ++$ct == scalar(@{$md}) ?  "\n" : ",";
  }
}
