#!/usr/bin/perl

use strict;
use DBI;
use IO::File;
use Getopt::Long;
use CBIL::Util::PropertySet;

my ($dbname, $gusConfigFile,$logDate, $outputFile);

&GetOptions('database|d=s' => \$dbname,
            'gusConfigFile|c=s' => \$gusConfigFile,
            'logDate|date=s' => \$logDate,
            'outputFileBase|o=s' => \$outputFile,
            );

die "usage: generateStatsByGenus -database|d <database> -logDate|date <date for logs ... eg 20210101 for the december 2020 log file> -gusConfigFile|c <configFile optional if in gus_home/config> -outputFileBase|f <output file base for tab delimited outputs>\n" unless $dbname && $logDate && $outputFile;

unless ($logDate){
  system("ssh watermelon ls /etc/httpd/logs/w1*/archive/access_log*");
  print STDERR "Enter numeric portion of a filename as the logDate\n";
  $logDate = <STDIN>;
  chomp $logDate;
}

#------- Uid and Password..these are fetched from the gus.cnfig file----------
$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

unless(-e $gusConfigFile) {
  print STDERR "gus.config file not found! \n";
  exit;
}

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);


my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect("dbi:Oracle:$dbname", $u, $pw) ||  die "Couldn't connect to database: " . DBI->errstr;

## my $sql = "select source_id, regexp_substr ( genus_species, '[A-z]*' ) as genus
## from webready.GeneAttributes";
my $sql = "select ga.source_id, 
regexp_substr ( ga.genus_species, '[A-z]*' ) as genus, 
ga.strain,
decode(oa.proteomicscount,0,0,1) as proteomics,
decode(oa.estcount,0,0,1) as ests,
decode(ga.total_hts_snps,0,0,1) as variation,
CASE WHEN oa.arraygenecount > 0 THEN 1 WHEN oa.rnaseqcount > 0 THEN 1 ELSE 0 END as transcriptomics,
CASE WHEN oa.chipchipgenecount > 0 THEN 1 WHEN oa.tfbscount > 0 THEN 1 ELSE 0 END as epigenomics,
oa.hasepitope as immunology,
CASE WHEN ta.ec_numbers is not null THEN 1 WHEN ta.ec_numbers_derived is not null THEN 1 ELSE 0 END as ecnumbers,
CASE WHEN ta.annotated_go_function is not null THEN 1 WHEN ta.predicted_go_function is not null THEN 1 ELSE 0 END as gofunction,
CASE WHEN ta.orthomcl_name is not null THEN 1 ELSE 0 END as has_orthology,
CASE WHEN (ta.tm_count >= 1 or ta.signalp_peptide is not null) THEN 1 ELSE 0 END as subcellularlocation
from webready.GeneAttributes ga, apidbtuning.organismattributes oa, webready.TranscriptAttributes ta
where ga.organism = oa.organism_name
and ta.source_id = ga.representative_transcript";

my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$sth->execute ||  die "Failed to  execute statement: " . $sth->errstr;

my %idData;

## TODO:  add queries to identify organisms specifically with different datatypes like phenotype etc that are shown on gene record page

while (my $row = $sth->fetchrow_hashref()) {
  $idData{$row->{SOURCE_ID}}->{genus} = $row->{GENUS};
  $idData{$row->{SOURCE_ID}}->{Epigenomics} += $row->{EPIGENOMICS};
  $idData{$row->{SOURCE_ID}}->{'Variation data'} += $row->{VARIATION};
  $idData{$row->{SOURCE_ID}}->{Transcriptomics} += $row->{TRANSCRIPTOMICS};
  $idData{$row->{SOURCE_ID}}->{Proteomics} += $row->{PROTEOMICS};
  $idData{$row->{SOURCE_ID}}->{'Enzyme commission'} += $row->{ECNUMBERS};
  $idData{$row->{SOURCE_ID}}->{'Gene Ontology'} += $row->{GOFUNCTION};
  $idData{$row->{SOURCE_ID}}->{'Gene Orthology'} += $row->{HAS_ORTHOLOGY};
  $idData{$row->{SOURCE_ID}}->{Immunology} += $row->{IMMUNOLOGY};
  $idData{$row->{SOURCE_ID}}->{ESTs} += $row->{ESTS};
  ##should add phenotype if genus Trypanosoma or Toxoplasma  ... really need to do some finer grained queries but no time now
  $idData{$row->{SOURCE_ID}}->{Phenotype} += $row->{STRAIN} =~ /(ME49|brucei TREU927)/ ? 1 : 0;
  $idData{$row->{SOURCE_ID}}->{'Subcellular localization'} += $row->{STRAIN} =~ /(ME49|brucei TREU927|3D7|isolate WB)/ || $row->{SUBCELLULARLOCATION} == 1;

  
}

print STDERR "total IDs from $dbname: ".scalar(keys%idData)."\n";

my $orgSQL = " select regexp_substr ( organism_name, '[A-z]*' ) as genus,count(*) as total, count(distinct species) as tot_species,
decode(project_id,'VectorBase','Vectors','FungiDB','Fungi','HostDB','Host','Protozoa') as domain 
from apidbtuning.organismattributes
where is_annotated_genome = 1
group by regexp_substr ( organism_name, '[A-z]*' ), decode(project_id,'VectorBase','Vectors','FungiDB','Fungi','HostDB','Host','Protozoa') "; 
my $osth = $dbh->prepare($orgSQL) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$osth->execute ||  die "Failed to  execute statement: " . $sth->errstr;

my %orgCt;

while (my @row = $osth->fetchrow_array()) {
  $orgCt{$row[0]} = [$row[1],$row[2],$row[3]];
}

$dbh->disconnect();

my @com;
my @servers = ("watermelon.uga.apidb.org", "fir.penn.apidb.org");

my $tot = 0;
my %taxa;
my %dataTypes;
my %search;
my %tools;
foreach my $s (@servers){
  my $cmd = "ssh $s ls /etc/httpd/logs/w*/archive/access_log-".$logDate.".gz";
  foreach my $f (`$cmd`){
    chomp $f;
#    next unless $f =~ /(tritrypdb|giardiadb)/;  ##for testing so just do a smaller number
    next if $f =~ /(clinepidb|orthomcl|microbiomedb|schistodb|static)/;
    print STDERR "Processing $s: $f\n";
    foreach my $l (`ssh $s zcat $f`){
      #    print STDERR $l;
#      next if $l =~ /bot\.html/;
#      next if $l =~ /download/;
      if($l =~ /POST.*record\/gene\/(\S+)\"/){
        next unless($idData{$1});
        $tot++;
        &countPage($1);
      }
      ##popsetSequence
      if($l =~ /POST.*record\/popsetSequence\/(\S+)\"/){
        $dataTypes{'Isolate data'}++;
      }
      #compound
      if($l =~ /POST.*record\/compound\/(\S+)\"/){
        $dataTypes{'Compounds'}++;
      }
      #pathways
      if($l =~ /POST.*record\/pathway\/\w+\/(\S+)\"/){
        $dataTypes{'Metabolic pathways'}++;
      }
      #ESTs
      if($l =~ /POST.*record\/est\/(\S+)\"/){
        $dataTypes{'ESTs'}++;
      }
      #SNPs
      if($l =~ /POST.*record\/snp.*?\/(\S+)\"/){
        $dataTypes{'Variation data'}++;
      }

      ##now searches but only does site search as this is the only one with organism= in the log files and only does when organisms are constrained
      if($l =~ /search.*organisms/){
        undef %search;
        while($l =~ m/organisms=(\w+)/g){
          $search{$1} = 1;
        }
        foreach my $a (keys%search){
          $taxa{$a}++;
        }
      }

      ##tools
      # Sequence retrieval tool
      $tools{'Sequence retrieval tool'}++ if $l =~ /(srt|Srt)/; 
      # Site Search
      $tools{'Site Search'}++ if $l =~ /site-search/; 
      # Multiple sequence alignment
      $tools{'Multiple sequence alignment'}++ if $l =~ /cgi-bin\/isolateAlignment/; 
      # Results downloads
      $tools{'Results downloads'}++ if $l =~ /\/reports\/(attributesTabular|tableTabular|gff3|fullRecord|xml|json)/; 
      # Apollo
      $tools{'Apollo'}++ if $l =~ /apollo_help/; 

    }
  }
}

open(F,">$outputFile"."ByTaxa.tab") || die "unable to open $outputFile.tab for writing\n";
print F "Taxa\tDomain\tPage Views\t# of Species\t# of Genome Seqs\n";
 
print "total: $tot\n";
foreach my $t (sort{$taxa{$b} <=> $taxa{$a}}keys%taxa){
  next unless $orgCt{$t}->[0];
  print F "$t\t$orgCt{$t}->[2]\t$taxa{$t}\t$orgCt{$t}->[1]\t$orgCt{$t}->[0]\n";
  print "$t: $orgCt{$t}->[0] genomes, $orgCt{$t}->[1] species, $taxa{$t} pages\n";
}

close F;

##now print by datatype 
open(O,">$outputFile"."ByDataType.tab") || die "unable to open $outputFile.tab for writing\n";
print O "Data Type\tDomain\tPage Views\n";
foreach my $d (keys%dataTypes){
  print O "$d\tVEuPathDB\t$dataTypes{$d}\n"
}

close O;

##and now for tools
open(O,">$outputFile"."ByTool.tab") || die "unable to open $outputFile.tab for writing\n";
print O "Tool\tDomain\tSubmitted\tCompleted\n";
foreach my $t (keys%tools){
  print O "$t\tVEuPathDB\t$tools{$t}\t$tools{$t}\n"
}

close O;
  


sub countPage {
  my($source_id) = shift;
  $taxa{$idData{$source_id}->{genus}}++;
  foreach my $key (keys%{$idData{$source_id}}){
    next if $key eq 'genus';
    $dataTypes{$key} += $idData{$source_id}->{$key};
  }
  ### need to add in genome, genomic sequence, etc that are present on all gene pages.
  my @types = ('Taxonomy','Genomes','Genome sequences','Genes/Proteins', 'Protein domains','Synteny');
  foreach my $key (@types){
    $dataTypes{$key}++;
  }
}
