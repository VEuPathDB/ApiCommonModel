#!/usr/bin/perl

use lib "$ENV{GUS_HOME}/lib/perl";

use strict;

use DBI;
use DBD::Oracle;
use Getopt::Long qw(GetOptions);

use Data::Dumper;

my ($login, $password, $dbInstances,$truncateTables);

GetOptions("login=s" => \$login,
           "password=s" => \$password,
           "dbInstances=s" => \$dbInstances,
           "truncateTables=s" => \$truncateTables
           );

unless ($login && $password && $dbInstances && $truncateTables){
   print STDERR "--login --password --dbInstances <comma delimted list of database instances> --truncateTables <comma delimted list of tables to truncate>\n";
   exit;
}

my @dbs = split(/\,/, $dbInstances);
my @tables = split(/\,/, $truncateTables);


foreach my $db (@dbs){
   my $dbDsn = "dbi:Oracle:$db";
   my $dbDbh = DBI->connect($dbDsn,$login,$password) or die DBI->errstr;
   $dbDbh->{RaiseError} = 1;
   $dbDbh->{AutoCommit} = 1;

   foreach my $table (@tables){
      my $sql = "truncate table $table";
      my $sh = $dbDbh->prepare($sql);
      $sh->execute();
      $sh->finish();
   }

 $dbDbh->disconnect();
}
