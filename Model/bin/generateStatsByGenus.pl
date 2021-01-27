#!/usr/bin/perl

use strict;
use DBI;
use IO::File;
use Getopt::Long;
use CBIL::Util::PropertySet;

my ($dbname, $gusConfigFile,$logDate);

&GetOptions('database|db=s' => \$dbname,
            'gusConfigFile|c=s' => \$gusConfigFile,
            'logDate|date=s' => \$logDate,
            );

die "usage: generateStatsByGenus -database|d <database> -logDate|date <date for logs ... eg 20210101 for the december 2020 log file> -gusConfigFile|c <configFile optional if in gus_home/config>\n" unless $dbname && $logDate;

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
$com[0] = "ssh watermelon zcat /etc/httpd/logs/w1*/archive/access_log-".$logDate.".gz";
$com[1] = "ssh fir zcat /etc/httpd/logs/w2*/archive/access_log-".$logDate.".gz";
## for testing
#$com[0] = "ssh watermelon cat /etc/httpd/logs/w1.plasmodb.org/access_log";
#$com[1] = "ssh fir cat /etc/httpd/logs/w2.plasmodb.org/access_log";

my $tot = 0;
my %taxa;
foreach my $s (@servers){
  my $cmd = "ssh $s ls /etc/httpd/logs/w*/archive/access_log-".$logDate.".gz";
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
        $taxa{$idGenus{$1}}++;
      }
    }
  }
}
 
print "total: $tot\n";
foreach my $t (sort{$taxa{$b} <=> $taxa{$a}}keys%taxa){
  print "$t: $orgCt{$t} genomes, $taxa{$t} pages\n";
}

