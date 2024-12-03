#!/usr/bin/perl

use strict;
use File::Find;
use File::Basename;
use Getopt::Long;

my ($help, $outputDir, $buildNumber);
&GetOptions('help|h' => \$help,
	    'buildNumber=s' => \$buildNumber,
            'outputDir=s' => \$outputDir
            );
&usage() if($help);

&usage("ERROR: buildNumber not specfied.") if (!$buildNumber);


my $destRootDir = '/eupath/data/apiSiteFiles/webServices/UniDB/';
$destRootDir = $outputDir if ($outputDir);

# Using Sufen's staging dir for now - Dec 2024
my $stagingDirRoot = "/eupath/data/apiSiteFilesStaging/UniDB/shu_m/real/webServices/";

# Projects so far included in UniDB - Dec 2024
my @projects  = qw/PlasmoDB TriTrypDB VectorBase/;


print  "Number of projects to handle = " . ($#projects + 1) . "\n\n";

umask 002; # resulting files will have mode 0644, directories 0755


foreach my $p (@projects) {
#    print "\nHandling PROJECT = $p\n";
  my $destDir = "$destRootDir/build-$buildNumber";
  my $stagingDir = $stagingDirRoot . $p . "/release-CURRENT/";

  print "destDir = $destDir AND stagingDir = $stagingDir\n";

  opendir my $dir, $stagingDir or die "Cannot open directory: $!";
  my @files = grep { $_ ne '.' && $_ ne '..' } readdir $dir;
  #system ("mkdir $destDir");

  foreach my $f (@files) {
    print "rsync DIR: $f\n";
    #system("mkdir $destDir/$f");
    system ("rsync -T /eupath/data/apiSiteFiles/.lsyncd_ignore -rvL -pt --delete --log-format='%i %M %f  %b'  $stagingDir/$f $destDir;");
  }
  closedir $dir;
  ## fix permissions
  print "Fixing file permissions \n";
  find(\&fixPerm, $destDir);

  print "\nDone with PROJECT $p\n";
}



sub usage {
  my $e = shift;

  if($e) {
    print STDERR $e . "\n";
  }
  print STDERR "usage:  copyStagingFiles.pl  --buildNumber <NUM> (--outputDir <DIR>)\n";
  exit;
}

sub fixPerm {
  my $perm = -d $File::Find::name ? 0775 : 0664;
  chmod $perm, $File::Find::name;
}


1;
