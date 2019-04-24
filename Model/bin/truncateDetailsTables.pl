#!/usr/bin/perl
use strict;

use DBI;
use DBD::Oracle;

use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;

my ($dbInstances, $login, $password);
&GetOptions("dbInstances=s" => \$dbInstances,
            "login=s" => \$login,
            "password=s" => \$password);

#####dbInstances should be comma delimted with no spaces

my @instances = split(/\,/,$dbInstances);

my @dbs;

foreach my $instance (@instances) {
	push(@dbs,"dbi:Oracle:$instance");
}

foreach my $dbDsn (@dbs){
   my $dbDbh = DBI->connect($dbDsn,$login,$password) or die DBI->errstr;
   $dbDbh->{RaiseError} = 1;
   $dbDbh->{AutoCommit} = 0;

   my $sql = "TRUNCATE table apidb.genedetail";

  my $sh = $dbDbh->prepare($sql);
  $sh->execute();
  $sh->finish();

  my $sql2 = "TRUNCATE table apidb.sequencedetail";

  my $sh2 = $dbDbh->prepare($sql2);
  $sh2->execute();
  $sh2->finish(); 

  my $sql2 = "TRUNCATE table apidb.isolatedetail";

  my $sh2 = $dbDbh->prepare($sql2);
  $sh2->execute();
  $sh2->finish();

  my $sql2 = "TRUNCATE table apidb.compounddetail";

  my $sh2 = $dbDbh->prepare($sql2);
  $sh2->execute();
  $sh2->finish();

 $dbDbh->disconnect();
}
