#!/usr/bin/perl

use strict;
use Getopt::Long;

# allows replacement of old_string with new_string - both mentioned in a file
# with tab-separated values (first old, then new).
# includes contents of replace.pl in a loop


my($ask,$nb,$infile);

&GetOptions("file=s" => \$infile,
            "i!"=> \$ask,
            "nb!" => \$nb,
            );

if (!$infile){
print <<endOfUsage;
Replace.perl usage:

  replaceStringsInFile.pl -i (ask first) -nb (don't backup) -old \"string to be replaced\" -new \"string to replace it with\" <filenames>

  if you use the -i option then you will be asked to confirm each replacement

  A time-stamped-copy will be made of the original file for backup purposes unless -nb.

endOfUsage
}

open (IN, "$infile");
while (<IN>) {
  chomp;
  my ($old, $new)= split(/\t/, $_);
  print "old=$old  AND new=$new\n";

  my $matchLen = length($old);

  foreach my $file (@ARGV){
    my $new_file = "";
    my $replace = 0;
    open (F, "$file");
    my $len = length($file);
    $len += 3;
    while (<F>) {
      my $dnrp = 0;
      my $rpc = 0;
      while (m/$old/g) {
	if ( $ask ) {
	  print "$file:  $_".&getChars(" ",$len + pos($_) - $matchLen).&getChars("-",$matchLen)."\n(y|n)? ";
	  my $ans = <STDIN>;
	  if ( $ans =~ /^y/i ) {
	    $replace++;
	    $_ =~ s|$old|RPLC975|;
	    $rpc = 1;
	  }elsif ( length($ans) > 2 ) {  #provide an alternate replacement
	    chomp($ans);
	    $replace++;
	    $_ =~ s|$old|$ans|;
	    $rpc = 1;
	  }else{
	    $dnrp = 1;
	    $_ =~ s|$old|DNRPC123|;
	  }
	}else {
	  $replace++;
	  $_ =~ s|$old|RPLC975|;
	  $rpc = 1;
	}
      } 
      $_ =~ s|DNRPC123|$old|g if $dnrp;
      $_ =~ s|RPLC975|$new|g if $rpc;
      $new_file .= $_;
    }
    if ( $replace >= 1) {
      print "$replace replacements made in $file\n";
      system ("cp $file $file.bak") unless $nb;
      open (OUT, ">$file");
      print OUT $new_file;
      close OUT;
    }
  }
}
##returns string of chars of specified length
sub getChars {
  my($char,$length) = @_;
  my $ret = "";
  for(my $i = 0;$i<$length;$i++){
    $ret .= $char;
  }
  return $ret;
}
