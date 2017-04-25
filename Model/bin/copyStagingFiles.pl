#!/usr/bin/perl

use strict;
use File::Find;
use File::Basename;
use Getopt::Long;

my ($help, $configFile, $outputDir, $includeProjects, $buildNumber, $mercator);
&GetOptions('help|h' => \$help,
	    'mercator=s' => \$mercator,
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
    @projects  = qw/AmoebaDB CryptoDB GiardiaDB HostDB MicrosporidiaDB PiroplasmaDB PlasmoDB ToxoDB TriTrypDB TrichDB SchistoDB FungiDB/;
} else {
    @projects = split (',' , $includeProjects);
}

print  "Number of projects to handle = " . ($#projects + 1) . "\n\n";

# build hash of project_id and staging_dir
my %stagingDir;
open (IN, "$configFile") || die "ERROR: Couldn't open prop file '$configFile'\n";;
while (<IN>) {
  chomp;
  $stagingDir{$1} = $2   if ($_ =~/^(.*)\t(.*)$/  );
}
close (IN);



# for each specified project
foreach my $p (@projects) {
    print "\nHandling PROJECT = $p\n"; #BB
    die "ERROR: No entry in config file for $p\n" if !($stagingDir{$p});

    umask 002; # resulting files will have mode 0644, directories 0755

    my $destDir = "$destRootDir$p/build-$buildNumber";

    opendir my $dir, $stagingDir{$p} or die "Cannot open directory: $!";
    my @files = grep { $_ ne '.' && $_ ne '..' } readdir $dir;
    #system ("mkdir $destDir");

    foreach my $f (@files) {
      if ( $f ne 'mercator_pairwise'){
	print "rsync DIR: $f\n";
	#system("mkdir $destDir/$f");
	system ("rsync -T /eupath/data/apiSiteFiles/.lsyncd_ignore -rvL -pt --delete --log-format='%i %M %f  %b'  $stagingDir{$p}/$f $destDir;");
      }
      elsif ($mercator ne "no") {
	print "FOR Mercator files\n";
	system ("mkdir $destDir/$f") unless(-e ($destDir ."/".$f));
	print "dir is $stagingDir{$p}/$f\n\n\n\n";

	system ("rsync -T /eupath/data/apiSiteFiles/.lsyncd_ignore -rvL -pt --delete --log-format='%i %M %f  %b' --prune-empty-dirs --include '*/' --include 'map' --include '*.agp' --exclude '*' $stagingDir{$p}/$f $destDir;");


	system("find $stagingDir{$p}${f}  -type f | grep -e '[.]mfa\$' | while read ; do DN=`dirname \$REPLY | sed 's|$stagingDir{$p}||'`;FN=`basename \$REPLY`; mkdir -p $destDir/\$DN; gzip < \$REPLY > $destDir/\$DN/\$FN.gz; done;");

	print "END\n";
      }
    }
    closedir $dir;


    ## fix permissions
    print "Fixing file permissions \n";
    find(\&fixPerm, $destDir);

    print "\n$p - DONE\n";
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
