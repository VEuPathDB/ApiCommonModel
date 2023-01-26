#!/usr/bin/perl

use strict;
use File::Find;
use File::Basename;
use Getopt::Long;

my ($help, $configFile, $outputDir, $includeProjects, $buildNumber);
&GetOptions('help|h' => \$help,
            'configFile=s' => \$configFile,
	    'includeProjects=s' => \$includeProjects,
	    'buildNumber=s' => \$buildNumber,
            'outputDir=s' => \$outputDir
            );
&usage() if($help);

&usage("ERROR: configFile not specfied.") unless(-e $configFile);
&usage("ERROR: buildNumber not specfied.") if (!$buildNumber);


my $destRootDir = '/eupath/data/apiSiteFiles/webServices/';
$destRootDir = $outputDir if ($outputDir);

my @projects ;
if ($includeProjects eq 'ALL'){
    @projects  = qw/AmoebaDB CryptoDB GiardiaDB HostDB MicrosporidiaDB PiroplasmaDB PlasmoDB ToxoDB TriTrypDB TrichDB FungiDB VectorBase/;
} else {
    @projects = split (',' , $includeProjects);
}

print  "Number of projects to handle = " . ($#projects + 1) . "\n\n";

# build hash of project_id and staging_dir
my %stagingDir;
my $d;
open (IN, "$configFile") || die "ERROR: Couldn't open prop file '$configFile'\n";;

while (<IN>) {
  chomp;
  if ($_ =~/^(.*)\t(.*)$/  ){
    if ($1 ne 'OrthoMCL'){
      $d = $2 . 'webServices/' . $1 . '/release-CURRENT/';
    } else {
      $d = $2 . 'webServices/' . $1 . '/build-CURRENT/';
    }

    $stagingDir{$1} = $d;
  }
}
close (IN);



# for each specified project
foreach my $p (@projects) {
    print "\nHandling PROJECT = $p\n";
    die "ERROR: No entry in config file for $p\n" if !($stagingDir{$p});

    umask 002; # resulting files will have mode 0644, directories 0755

    my $destDir = "$destRootDir$p/build-$buildNumber";

    opendir my $dir, $stagingDir{$p} or die "Cannot open directory: $!";
    my @files = grep { $_ ne '.' && $_ ne '..' } readdir $dir;
    #system ("mkdir $destDir");

    foreach my $f (@files) {
      print "rsync DIR: $f\n";
      #system("mkdir $destDir/$f");
      system ("rsync -T /eupath/data/apiSiteFiles/.lsyncd_ignore -rvL -pt --delete --log-format='%i %M %f  %b'  $stagingDir{$p}/$f $destDir;");
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
  print STDERR "usage:  copyStagingFiles.pl --configFile <FILE>  --includeProjects <LIST|EuPath|ALL> --buildNumber <NUM> (--outputDir <DIR>)\n";
  exit;
}

sub fixPerm {
  my $perm = -d $File::Find::name ? 0775 : 0664;
  chmod $perm, $File::Find::name;
}


1;
