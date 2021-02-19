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
            'outputFile|o=s' => \$outputFile,
            );

die "usage: generateStatsByGenus -database|d <database> -logDate|date <date for logs ... eg 20210101 for the december 2020 log file> -gusConfigFile|c <configFile optional if in gus_home/config> -outputFile|f <output file for tab delimited output>\n" unless $dbname && $logDate;

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

my $sql = "select source_id, regexp_substr ( genus_species, '[A-z]*' ) as genus
from apidbtuning.geneattributes";

my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$sth->execute ||  die "Failed to  execute statement: " . $sth->errstr;

my %idGenus;

while (my @row = $sth->fetchrow_array()) {
  $idGenus{$row[0]} = $row[1];
}

print STDERR "total IDs from $dbname: ".scalar(keys%idGenus)."\n";

my $orgSQL = "select regexp_substr ( organism_name, '[A-z]*' ) as genus,count(*) from apidbtuning.organismattributes
where is_annotated_genome = 1
group by regexp_substr ( organism_name, '[A-z]*' )";

my $osth = $dbh->prepare($orgSQL) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
$osth->execute ||  die "Failed to  execute statement: " . $sth->errstr;

my %orgCt;

while (my @row = $osth->fetchrow_array()) {
  $orgCt{$row[0]} = $row[1];
}

$dbh->disconnect();

my @com;
my @servers = ("watermelon", "fir");

my $tot = 0;
my %gptaxa;
my %staxa;
my %search;
foreach my $s (@servers){
  my $cmd = "ssh $s ls /etc/httpd/logs/w*/archive/access_log-".$logDate.".gz";
#  my $cmd = "ssh $s ls /etc/httpd/logs/w1.plasmodb.org/archive/access_log-".$logDate.".gz";
  foreach my $f (`$cmd`){
    chomp $f;
    next if $f =~ /(clinepidb|orthomcl|microbiomedb|static)/;
    print STDERR "Processing $s: $f\n";
    foreach my $l (`ssh $s zcat $f`){
      #    print STDERR $l;
      next if $l =~ /bot\.html/;
      next if $l =~ /download/;
      if($l =~ /GET\s\S*record\/gene\/(\S*)/){
        unless($idGenus{$1}){
          #        print STDERR "'$1'\n";
          next; 
        }
        $tot++;
        $gptaxa{$idGenus{$1}}++;
      }
      ##now searches
      if($l =~ /search.*organisms/){
        undef %search;
        while($l =~ m/organisms=(\w+)/g){
          $search{$1} = 1;
        }
        foreach my $a (keys%search){
          $staxa{$a}++;
        }
      }
    }
  }
}

if($outputFile){
  open(F,">$outputFile") || die "unable to open $outputFile for writing\n";
  print F "genus\tgenomeCt\tpageCt\tsearchCt\n";
}
 
print "total: $tot\n";
foreach my $t (sort{$gptaxa{$b} <=> $gptaxa{$a}}keys%gptaxa){
  next unless $orgCt{$t};
  print F "$t\t",$orgCt{$t} ? "$orgCt{$t}\t" : "0\t",$gptaxa{$t} ? "$gptaxa{$t}\t" : "0\t",$staxa{$t} ? "$staxa{$t}\n" : "0\n" if $outputFile;
  print "$t: $orgCt{$t} genomes, ",$gptaxa{$t} ? "$gptaxa{$t}" : "0"," pages, ",$staxa{$t} ? "$staxa{$t}" : "0"," searches\n";
  delete $staxa{$t};  ##remove so can generate numbers for any remaining
}

foreach my $t (sort{$staxa{$b} <=> $staxa{$a}}keys%staxa){
  print F "$t\t",$orgCt{$t} ? "$orgCt{$t}\t" : "0\t",$gptaxa{$t} ? "$gptaxa{$t}\t" : "0\t",$staxa{$t} ? "$staxa{$t}\n" : "0\n" if $outputFile;
  print "$t: $orgCt{$t} genomes, ",$gptaxa{$t} ? "$gptaxa{$t}" : "0"," pages, ",$staxa{$t} ? "$staxa{$t}" : "0"," searches\n";
}

close F;
