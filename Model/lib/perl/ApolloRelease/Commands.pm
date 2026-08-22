package ApiCommonModel::Model::ApolloRelease::Commands;

use strict;
use warnings;

# Emits the commands a human runs against Apollo once the release package has
# been synced.  This module NEVER executes anything and never opens a socket:
# its whole output is text destined for two files.  That is deliberate.  The
# same inputs that produce a correct release produce, with one field wrong, an
# irreversible loss of curated annotations -- so the step between "computed"
# and "applied" is a file a human reads.
#
# Passwords are emitted as the shell variable $APOLLO_ADMIN_PASSWORD, never
# interpolated: these files land in a shared directory and get pasted into
# tickets.

my $API   = 'https://apollo-api.veupathdb.org';
my $UI    = 'https://apollo.apidb.org';
my $DATA  = '/data/apollo_data';
my $ADMIN = 'admin@local.host';

# Every curl command is the same call -- updateOrganismInfo -- differing only
# in which id it names and what it sets.  Keeping one emitter means a change to
# quoting, endpoint or credentials cannot apply to three of the four kinds.
#
# Field order is fixed rather than hash order so two runs over the same
# reconciliation produce byte-identical files; a diff between releases is then
# a diff of decisions, not of Perl's hash seed.
sub _updateOrganismInfo {
  my ($class, $id, $abbrev, $extra) = @_;

  die "_updateOrganismInfo: no apollo id\n"     unless defined $id && length $id;
  die "_updateOrganismInfo: no abbrev\n"        unless defined $abbrev && length $abbrev;

  my %fields = (
    username  => $ADMIN,
    password  => '$APOLLO_ADMIN_PASSWORD',
    id        => "$id",
    directory => "$DATA/$abbrev",
    blatdb    => "$DATA/twoBit/$abbrev.2bit",
    %{$extra || {}},
  );

  my @fixed = qw(username password id directory blatdb);
  my %isFixed = map { $_ => 1 } @fixed;
  my @order = (@fixed, grep { !$isFixed{$_} } sort keys %fields);

  # A single quote in a value would terminate the shell's quoting of --data and
  # turn the rest of the JSON into shell words.  commonName comes from the
  # portal, so this is reachable in principle; refuse rather than emit a line
  # whose meaning depends on the shell.
  foreach my $key (@order) {
    die "$key value contains a single quote, which the emitted shell command "
      . "cannot quote safely: $fields{$key}\n"
      if $fields{$key} =~ /'/;
    die "$key value contains a double quote or backslash, which would break "
      . "the emitted JSON: $fields{$key}\n"
      if $fields{$key} =~ /["\\]/;
  }

  my $json = join(',', map { qq{"$_":"$fields{$_}"} } @order);

  return qq{curl -X POST -H "Content-Type: application/json" }
       . qq{--data '{$json}' $API/organism/updateOrganismInfo\n};
}

# Apollo names an organism "<full name> [<annotation version>]".  With no
# usable history row Portal leaves latest_annotation_version undef; emit the
# bare name rather than an empty "[]", which would become part of the
# organism's identity in Apollo and never match a later release.
sub apolloName {
  my ($class, $organism) = @_;

  die "apolloName: no organism record\n" unless $organism;
  my $name = $organism->{name};
  die "apolloName: organism has no name\n" unless defined $name && length $name;

  my $version = $organism->{latest_annotation_version};

  return (defined $version && length $version) ? "$name [$version]" : $name;
}

# An update must NOT change visibility.  Publishing and unpublishing are
# curation decisions: 17 live organisms are deliberately hidden, three of them
# carrying annotations.  The previous script hardcoded "publicMode":"true"
# here, which re-published every one of them.  Echo back what Apollo currently
# holds -- and if we were not told what that is, die.  A default is exactly how
# that bug returns, because a default looks correct in every test where the
# field happens to be present.
sub updateCommand {
  my ($class, $entry) = @_;

  die "updateCommand: public_mode missing for $entry->{abbrev}; refusing to guess visibility\n"
    unless defined $entry->{public_mode};

  return $class->_updateOrganismInfo(
    $entry->{apollo_id}, $entry->{abbrev},
    {publicMode => $entry->{public_mode} ? 'true' : 'false'},
  );
}

# A rename repoints the EXISTING organism: same id, new directory, new blatdb,
# new commonName.  cneoJEC21 (id 2452162) holds 14 human-made annotations and
# has been reclassified as cdenJEC21; repointing that id preserves them.
#
# The wrong shape -- add the new abbrev, prune the old -- uses the same API and
# the same inputs, succeeds, and produces an empty organism plus 14 orphaned
# annotations.  Nothing downstream can tell the two apart, which is why the id
# used here is the old organism's and the paths are the new abbrev's.
sub renameCommand {
  my ($class, $entry) = @_;

  die "renameCommand: public_mode missing for $entry->{from_abbrev}; refusing to guess visibility\n"
    unless defined $entry->{public_mode};

  return $class->_updateOrganismInfo(
    $entry->{apollo_id}, $entry->{to_abbrev},
    {publicMode => $entry->{public_mode} ? 'true' : 'false',
     commonName => $class->apolloName($entry->{organism})},
  );
}

# Prune UNPUBLISHES.  It is reversible by a single field flip, and Apollo's API
# has no delete in use.  A prune is generated from the absence of an organism
# on the portal -- a weaker signal than a curator's decision to keep data -- so
# the action it triggers must be the recoverable one.
sub pruneCommand {
  my ($class, $entry) = @_;

  return $class->_updateOrganismInfo(
    $entry->{apollo_id}, $entry->{abbrev},
    {publicMode => 'false'},
  );
}

# An add creates an organism that does not exist in Apollo, then grants the
# remote_users group access to it.  Unlike the curl commands this is NOT
# idempotent -- a second run adds a second organism with the same name -- which
# is why adds live in their own file and are never mixed into Apollo_curl.
sub addCommand {
  my ($class, $entry) = @_;

  my $abbrev = $entry->{abbrev};
  die "addCommand: no abbrev\n" unless defined $abbrev && length $abbrev;

  my $name = $class->apolloName($entry->{organism});

  die "addCommand: organism name contains a single quote and cannot be "
    . "shell-quoted safely: $name\n" if $name =~ /'/;

  return
    qq{groovy add_organism.groovy -name '$name' -url $UI }
  . qq{-directory '$DATA/$abbrev' -blatdb '$DATA/twoBit/$abbrev.2bit' }
  . qq{-username '$ADMIN' -password \$APOLLO_ADMIN_PASSWORD\n}
  . qq{groovy alter_group_permissions.groovy -groupname remote_users }
  . qq{-organism '$name' -permission WRITE -destinationurl $UI/ }
  . qq{-adminusername '$ADMIN' -adminpassword \$APOLLO_ADMIN_PASSWORD\n};
}

# Writes the two files a human runs.  Ordering is part of the contract:
#
#   renames first  -- they are the only commands whose target holds curated
#                     work, so if a run is interrupted they are the ones that
#                     have already landed;
#   updates next   -- pure repointing, no organism changes identity;
#   prunes last    -- an interrupted run then leaves everything published,
#                     which is the recoverable end state.
#
# ONLY APPROVED adds and prunes are emitted.  An unapproved candidate is a
# proposal for a human, reported by Report.pm; turning it into a runnable line
# would make the roster overlay advisory rather than the gate it is.
sub writeCommandFiles {
  my ($class, $result, $dir, %opts) = @_;

  die "writeCommandFiles: no output directory\n" unless defined $dir && length $dir;

  my @renames = @{$result->{rename}          || []};
  my @updates = @{$result->{update}          || []};
  my @prunes  = grep { $_->{approved} } @{$result->{prune_candidate} || []};
  my @adds    = grep { $_->{approved} } @{$result->{add_candidate}   || []};

  my $curlPath   = "$dir/Apollo_curl";
  my $groovyPath = "$dir/Apollo_groovy";

  open(my $curl, '>', $curlPath) or die "Cannot write $curlPath: $!";
  print $curl $class->_header(
    'Apollo_curl',
    \%opts,
    sprintf('%d rename(s), %d update(s), %d approved prune(s)',
            scalar @renames, scalar @updates, scalar @prunes),
    'Order matters: renames, then updates, then prunes.  Run the file top to',
    'bottom.  Re-running it is safe -- every line sets the same fields to the',
    'same values.',
  );
  print $curl $class->renameCommand($_) for @renames;
  print $curl $class->updateCommand($_) for @updates;
  foreach my $prune (@prunes) {
    # An approved prune of an annotated organism is still emitted: approval is
    # the human gate, and unpublishing is reversible.  But it is never silent
    # -- whoever runs the file is told, on the line above, what is about to
    # become invisible.
    my $count = $prune->{annotation_count} || 0;
    print $curl "# WARNING: $prune->{abbrev} has $count human annotation(s); "
              . "unpublishing hides them.\n" if $count;
    print $curl $class->pruneCommand($prune);
  }
  close $curl or die "Cannot close $curlPath: $!";

  open(my $groovy, '>', $groovyPath) or die "Cannot write $groovyPath: $!";
  print $groovy $class->_header(
    'Apollo_groovy',
    \%opts,
    sprintf('%d approved add(s)', scalar @adds),
    'NOT idempotent: running this file twice creates duplicate organisms.',
  );
  print $groovy $class->addCommand($_) for @adds;
  close $groovy or die "Cannot close $groovyPath: $!";

  return {curl => $curlPath, groovy => $groovyPath};
}

# The header is comment lines, so the file stays runnable as a shell script.
# It exists because these files outlive the run that made them: they are copied
# into tickets and read weeks later, at which point "which build is this, and
# does it still apply?" has no other answer.  The date is caller-supplied where
# possible so a regenerated package is byte-comparable with its predecessor.
sub _header {
  my ($class, $fileName, $opts, @lines) = @_;

  my $date = $opts->{date};
  unless (defined $date) {
    my @t = gmtime(time);
    $date = sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]);
  }

  my $build = defined $opts->{build} ? $opts->{build} : 'unspecified';

  return join('', map { "# $_\n" }
    "$fileName -- generated by createApolloReleasePackage",
    "build $build, generated $date",
    @lines,
    'Passwords are not stored here: export APOLLO_ADMIN_PASSWORD before running.',
  ) . "#\n";
}

1;
