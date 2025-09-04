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

# full ReflowPlus  - Apr 2025
my $stagingDirRoot = "/veupath/data/websiteFilesStaging/GenomicsDB/ReflowPlus/real/webServices/"; # if ($buildNumber eq "70");

# Sufen's staging dirs  - Dec 2024
$stagingDirRoot = "/eupath/data/apiSiteFilesStaging/UniDB/shu_A/real/webServices/" if ($buildNumber eq "999.1");
$stagingDirRoot = "/eupath/data/apiSiteFilesStaging/UniDB/shu_B/real/webServices/" if ($buildNumber eq "999.2");

my @projects;
if ($buildNumber eq "70"){
    @projects  = qw/AmoebaDB CryptoDB FungiDB GiardiaDB HostDB MicrosporidiaDB PiroplasmaDB PlasmoDB ToxoDB TrichDB TriTrypDB/;
} else {
    @projects  = qw/PlasmoDB ToxoDB TriTrypDB VectorBase/;
}

print  "Number of projects to handle = " . ($#projects + 1) . "\n\n";

umask 002; # resulting files will have mode 0644, directories 0755


foreach my $p (@projects) {
#    print "\nHandling PROJECT = $p\n";
  my $destDir = "$destRootDir/build-$buildNumber";
  my $stagingDir = $stagingDirRoot . $p . "/release-CURRENT/";

  print "destDir = $destDir AND stagingDir = $stagingDir\n";

  #opendir my $dir, $stagingDir or die "Cannot open directory: $!";
  opendir my $dir, $stagingDir or die "Cannot open directory: $!" .  "AND destDir = $destDir AND stagingDir = $stagingDir";
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
