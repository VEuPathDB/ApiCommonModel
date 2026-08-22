use strict;
use warnings;
use Test::More tests => 6;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JBrowseUtil;

my $U = 'ApiCommonModel::Model::JBrowseUtil';

# This file guards ONE failure mode, the one that killed jbrowseRefSeqs for a
# year and a half: an accessor is removed from JBrowseUtil while a caller keeps
# calling it.  Perl resolves methods at run time, so nothing -- not compilation,
# not `perl -c`, not any other test here -- notices.  The script dies at its
# first line of real work with `Can't locate object method`.
#
# It matters more than an ordinary missing-method bug because these scripts are
# served through responseFromCommand, which merges stderr into the JSON response
# body.  A dead method is a corrupt payload on the live site, not a log line.

# Every method invoked on a JBrowseUtil instance by the shipped jbrowse*
# scripts must exist on the package.  Scanning the scripts rather than listing
# the methods here is deliberate: a new script gets covered for free, and the
# assertion cannot drift out of date the way a hand-kept list would.
my @scripts = sort glob('Model/bin/jbrowse*');
ok(scalar(@scripts) >= 9, 'found the jbrowse* scripts to scan') or diag("cwd must be the ApiCommonModel checkout root");

my @missing;
foreach my $script (@scripts) {
  open(my $fh, '<', $script) or die "Cannot read $script: $!";
  local $/;
  my $src = <$fh>;
  close $fh;

  next unless $src =~ /\Q$U\E->new/;

  my %seen;
  while ($src =~ /\$jbrowseUtil\s*->\s*(\w+)\s*\(/g) {
    next if $seen{$1}++;
    push @missing, "$script: \$jbrowseUtil->$1()" unless $U->can($1);
  }
}
is(join("\n", @missing), '', 'every JBrowseUtil method the jbrowse* scripts call exists')
  or diag("removed accessor still has callers -- the script dies at run time with 'Can't locate object method'");

# The caching path was retired by e0e9a61bb ("comment out stuff to do with
# CACHE"), which disabled the setter call in new() but left the callers behind.
# Restoring the accessors would have re-armed a cache that has no invalidation:
# _refSeqsCache.json is written once into GUS_HOME and then returned forever,
# outliving the build whose sequence lengths it holds.  It is gone, and these
# assertions exist so a future reader does not "restore" it by reflex.
foreach my $method (qw(getCacheFile setCacheFile setCacheFileName printFromCache)) {
  ok(!$U->can($method), "$method is gone, not re-armed: the refSeqs cache had no invalidation");
}
