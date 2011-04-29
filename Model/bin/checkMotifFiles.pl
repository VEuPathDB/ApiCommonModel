#!/usr/bin/perl

use strict;

use XML::Simple;

use DBI;
use DBD::Oracle;

use Getopt::Long;

use Data::Dumper;

#/eupath/data/apiSiteFiles/webServices/TriTrypDB/release-3.1/motif/

my ($help, $apiSiteFilesDir, $eupathDatabase);

&GetOptions('help|h' => \$help,
            'apiSiteFilesDir=s' => \$apiSiteFilesDir,
            'eupath_database=s' => \$eupathDatabase,
            );

unless(-d $apiSiteFilesDir) {
  &usage("ERROR:  apiSiteFiles Directory does not exist");
}

unless(lc($eupathDatabase) =~ /eupa[a|b][n|s]/) {
  &usage("ERROR:  EuPathDB Database must be specified as one of eupa[a|b][n|s]");
}
if($help) {
  &usage();
}

my $dbiDsn = 'dbi:Oracle:' . $eupathDatabase;

my $dbh = DBI->connect($dbiDsn) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

# model Files we will read
my $similarityParamsXml = $ENV{PROJECT_HOME} . "/ApiCommonShared/Model/lib/wdk/apiCommonModel/questions/params/similarityParams.xml";
my $apiCommonModelXml = $ENV{PROJECT_HOME} . "/ApiCommonShared/Model/lib/wdk/apiCommonModel.xml";

my $similarityParams = XMLin($similarityParamsXml, ForceArray => 1);
my $apiCommonModel = XMLin($apiCommonModelXml, ForceArray => 1);

my $orfSql =  $similarityParams->{querySet}->{SimilarityVQ}->{sqlQuery}->{OrfMotifFiles}->{sql}->[0];
my $genomicSql =  $similarityParams->{querySet}->{SimilarityVQ}->{sqlQuery}->{GenomicMotifFiles}->{sql}->[0];
my $annotatedProteinsSql =  $similarityParams->{querySet}->{SimilarityVQ}->{sqlQuery}->{AnnotatedProteinMotifFiles}->{sql}->[0];

$orfSql =~ s/\\'/'/;
$genomicSql =~ s/\\'/'/;
$annotatedProteinsSql =~ s/\\'/'/;

my %projectVersions;
foreach(@{$apiCommonModel->{modelName}}) {
  my $version = $_->{version};
  my $projectId = $_->{displayName};

  $projectVersions{$projectId} = $version;
}

# Get valid project ids
my $sh = $dbh->prepare("select distinct project_id from apidb.sequenceattributes");
$sh->execute();

while(my ($projectId) = $sh->fetchrow_array()) {
  next if($projectId eq 'OrphanDB');

  my $version = $projectVersions{$projectId};
  die "No version for project $projectId specified "unless($version);

  my $tempOrfSql = $orfSql;
  my $tempGenomicSql = $genomicSql;
  my $tempAnnotatedProteinsSql = $annotatedProteinsSql;

  $tempOrfSql =~ s/\@PROJECT_ID\@/$projectId/g;
  $tempGenomicSql =~ s/\@PROJECT_ID\@/$projectId/g;
  $tempAnnotatedProteinsSql =~ s/\@PROJECT_ID\@/$projectId/g;

  foreach my $sql ($tempOrfSql, $tempGenomicSql, $tempAnnotatedProteinsSql) {
    my $motifSh = $dbh->prepare($sql);
    $motifSh->execute();

    while(my ($organism, $file) = $motifSh->fetchrow_array()) {

      my $filename = "$apiSiteFilesDir/webServices/$projectId/release-$version/motif/$file";

      unless(-e $filename) {
        print "ERROR:  Expected file not found:  $filename\n";
      }
    }
    $motifSh->finish();
  }
}
$sh->finish();


sub usage {
  my $e = shift;

  if($e) {
    print STDERR $e . "\n";
  }
  print STDERR "usage:  checkBlastFiles.pl --apiSiteFilesDir <DIR> --eupath_database eupa[a|b][n|s]\n";
  exit;
}

$dbh->disconnect();
1;







