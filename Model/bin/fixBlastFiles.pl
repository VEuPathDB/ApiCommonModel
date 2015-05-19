#!/usr/bin/perl

use strict;

use XML::Simple;
use File::Basename;
use DBI;
use DBD::Oracle;
use Getopt::Long;

#use Data::Dumper;

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

my $failures = 0;
my $dbiDsn = 'dbi:Oracle:' . $eupathDatabase;

my $dbh = DBI->connect($dbiDsn) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

# model Files we will read
my $sharedParamsXml = $ENV{PROJECT_HOME} . "/ApiCommonShared/Model/lib/wdk/apiCommonModel/questions/params/sharedParams.xml";
my $apiCommonModelXml = $ENV{PROJECT_HOME} . "/ApiCommonShared/Model/lib/wdk/apiCommonModel.xml";

my $sharedParams = XMLin($sharedParamsXml, ForceArray => 1);
my $apiCommonModel = XMLin($apiCommonModelXml, keyattr=>[], ForceArray => 1);

my $blastDatabaseTypes = $sharedParams->{paramSet}->{sharedParams}->{enumParam}->{BlastDatabaseType}->{enumList}->[0]->{enumValue};
my $blastSql =  $sharedParams->{querySet}->{SharedVQ}->{sqlQuery}->{BlastOrganismFiles}->{sql}->[0];
$blastSql =~ s/\\'/'/;

my %projectVersions;

foreach(@{$apiCommonModel->{constant}}) {
  if ($_->{name} eq "buildNumber") {
    my $version = $_->{content};

    #  more than one project may be assigned the same buildNumber
    my @projects = split(',', $_->{includeProjects});
    foreach my $p (@projects) {
	$projectVersions{$p} = $version;
    }
  }
}

# Get valid project ids
my $sh = $dbh->prepare("select distinct project_id from ApidbTuning.GenomicSequenceAttributes");
$sh->execute();

while(my ($projectId) = $sh->fetchrow_array()) {
  next if($projectId eq 'OrphanDB');

  my $version = $projectVersions{$projectId};
  die "No version for project $projectId specified "unless($version);

  foreach my $blastType (@$blastDatabaseTypes) {

    my $tempBlastSql = $blastSql;
    my $includeProjects = $blastType->{includeProjects};
    my $excludeProjects = $blastType->{excludeProjects};

    next if($includeProjects && $includeProjects !~ /$projectId/);
    next if($excludeProjects && $excludeProjects =~ /$projectId/);

    my $internal = $blastType->{internal}->[0];

    $tempBlastSql =~ s/\@PROJECT_ID\@/$projectId/g;
    $tempBlastSql =~ s/\$\$BlastDatabaseType\$\$/$internal/g;

    my $blastSh = $dbh->prepare($tempBlastSql);
    $blastSh->execute();

    while(my ($parent, $organism, $file) = $blastSh->fetchrow_array()) {
      next if($file eq '-1');

      # example $file (in apiSiteFilesStaging) maybe: :
      # @WEBSERVICEMIRROR@/TriTrypDB/build-%%buildNumber%%/LbraziliensisMHOMBR75M2904/blast/LbraziliensisMHOMBR75M2904
      my $basename = basename($file);     # name of org ("LbraziliensisMHOMBR75M2904" for eg)
      my $dirname = dirname ($file);

      # make array of $extension
      my @extensionArr = ('.xnd', '.xns', '.xnt');
      if($internal eq 'AnnotatedProteins' || $internal eq 'ORFs_AA') {
	@extensionArr = ('.xpd', '.xps', '.xpt');
      }

      # prepend file name with organismName
      foreach my $extension (@extensionArr){
	my $oldLocation = "$apiSiteFilesDir$projectId/build-$version/$basename/blast/" . $internal . $extension;
	my $newLocation = "$apiSiteFilesDir$projectId/build-$version/$basename/blast/$basename" . $internal . $extension;

	if (-e $oldLocation) {
	  print  "mv $oldLocation $newLocation\n" ;
	} else {
	  print "ERROR:  Expected file not found:  $oldLocation\n";
	  $failures++;
	}
      }

    }
    $blastSh->finish();
  }
}
$sh->finish();
$dbh->disconnect();

print STDERR "Finished with $failures Errors\n";

sub usage {
  my $e = shift;

  if($e) {
    print STDERR $e . "\n";
  }
  print STDERR "usage:  fixBlastFiles.pl --apiSiteFilesDir <DIR> --eupath_database eupa[a|b][n|s]\n";
  exit;
}


1;







