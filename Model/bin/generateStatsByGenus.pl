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
## from apidbtuning.geneattributes";
my $sql = "select ga.source_id, regexp_substr ( ga.genus_species, '[A-z]*' ) as genus,
decode(oa.proteomicscount,0,0,1) as proteomics,decode(oa.estcount,0,0,1) as ests,decode(ga.total_hts_snps,0,0,1) as variation,
CASE WHEN oa.arraygenecount >= 0 THEN 1 WHEN oa.rnaseqcount >= 0 THEN 1 ELSE 0 END as transcriptomics,
CASE WHEN oa.chipchipgenecount >= 0 THEN 1 WHEN oa.tfbscount >= 0 THEN 1 ELSE 0 END as epigenomics,
oa.hasepitope as immunology,
CASE WHEN ta.ec_numbers is not null THEN 1 WHEN ta.ec_numbers_derived is not null THEN 1 ELSE 0 END as ecnumbers,
CASE WHEN ta.annotated_go_function is not null THEN 1 WHEN ta.predicted_go_function is not null THEN 1 ELSE 0 END as gofunction,
CASE WHEN ta.orthomcl_name is not null THEN 1 ELSE 0 END as has_orthology
from apidbtuning.geneattributes ga, apidbtuning.organismattributes oa, apidbtuning.transcriptattributes ta
where ga.organism = oa.organism_name
and ta.source_id = ga.representative_transcript";

my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$sth->execute ||  die "Failed to  execute statement: " . $sth->errstr;

my %idData;

while (my $row = $sth->fetchrow_hashref()) {
  $idData{$row->{SOURCE_ID}}->{genus} = $row->{GENUS};
  $idData{$row->{SOURCE_ID}}->{epigenomics} += $row->{EPIGENOMICS};
  $idData{$row->{SOURCE_ID}}->{variation} += $row->{VARIATION};
  $idData{$row->{SOURCE_ID}}->{transcriptomics} += $row->{TRANSCRIPTOMICS};
  $idData{$row->{SOURCE_ID}}->{proteomics} += $row->{PROTEOMICS};
  $idData{$row->{SOURCE_ID}}->{ecnumbers} += $row->{ECNUMBERS};
  $idData{$row->{SOURCE_ID}}->{gofunction} += $row->{GOFUNCTION};
  $idData{$row->{SOURCE_ID}}->{has_orthology} += $row->{HAS_ORTHOLOGY};
  $idData{$row->{SOURCE_ID}}->{immunology} += $row->{IMMUNOLOGY};
  $idData{$row->{SOURCE_ID}}->{ests} += $row->{ESTS};
}

print STDERR "total IDs from $dbname: ".scalar(keys%idData)."\n";

my $orgSQL = "select regexp_substr ( organism_name, '[A-z]*' ) as genus,count(*) as total, count(distinct species) as tot_species,
decode(project_id,'VectorBase','Vectors','FungiDB','Fungi','Protozoa') as domain 
from apidbtuning.organismattributes
where is_annotated_genome = 1
group by regexp_substr ( organism_name, '[A-z]*' ), decode(project_id,'VectorBase','Vectors','FungiDB','Fungi','Protozoa')";

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
foreach my $s (@servers){
  my $cmd = "ssh $s ls /etc/httpd/logs/w*/archive/access_log-".$logDate.".gz";
#  my $cmd = "ssh $s ls /etc/httpd/logs/w1.plasmodb.org/archive/access_log-".$logDate.".gz";
  foreach my $f (`$cmd`){
    chomp $f;
    last if $f =~ /hostdb/;  ##for testing so just do a smaller number
    next if $f =~ /(clinepidb|orthomcl|microbiomedb|schistodb|static)/;
    print STDERR "Processing $s: $f\n";
    foreach my $l (`ssh $s zcat $f`){
      #    print STDERR $l;
      next if $l =~ /bot\.html/;
      next if $l =~ /download/;
      if($l =~ /GET\s\S*record\/gene\/(\S*)/){
        unless($idData{$1}){
          #        print STDERR "'$1'\n";
          next; 
        }
        $tot++;
        &countPage($1);
      }
      ##now searches
      if($l =~ /search.*organisms/){
        undef %search;
        while($l =~ m/organisms=(\w+)/g){
          $search{$1} = 1;
        }
        foreach my $a (keys%search){
          $taxa{$a}++;
        }
      }
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
print O "Data Type\tDomain\tPage Views + Searches\n";
foreach my $d (keys%dataTypes){
  print O "$d\tVEuPathDB\t$dataTypes{$d}\n"
}

close O;


sub countPage {
  my($source_id) = shift;
  $taxa{$idData{$source_id}->{genus}}++;
  foreach my $key (keys%{$idData{$source_id}}){
    next if $key eq 'genus';
    $dataTypes{$key} += $idData{$source_id}->{$key};
  }
}
