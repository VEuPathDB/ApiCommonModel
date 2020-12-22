#!/usr/bin/perl

use strict;
use DBI;
use IO::File;
use Getopt::Long;
use CBIL::Util::PropertySet;

my ($dbname, $gusConfigFile);

&GetOptions('database|d=s' => \$dbname,
            'gusConfigFile|c=s' => \$gusConfigFile,
            );

die "usage: generateStatsByGenus database|d <database> gusConfigFile|c <conofigFile optional if in gus_home/config>\n" unless $dbname;

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

$dbh->disconnect();

my @com;
$com[0] = "ssh watermelon cat /etc/httpd/logs/w1*/access_log";
$com[1] = "ssh fir cat /etc/httpd/logs/w2*/access_log";
## for testing
#$com[0] = "ssh watermelon cat /etc/httpd/logs/w1.plasmodb.org/access_log";
#$com[1] = "ssh fir cat /etc/httpd/logs/w2.plasmodb.org/access_log";

my $tot = 0;
my %taxa;
foreach my $c (@com){
  foreach my $l (`$c`){
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
 
print "total: $tot\n";
foreach my $t (sort{$taxa{$b} <=> $taxa{$a}}keys%taxa){
  print "$t: $taxa{$t}\n";
}

