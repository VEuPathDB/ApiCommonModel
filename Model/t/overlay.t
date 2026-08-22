use strict;
use warnings;
use Test::More tests => 18;
use FindBin;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Overlay;

my $O = 'ApiCommonModel::Model::ApolloRelease::Overlay';

my $text = <<'OVERLAY';
# comment line, ignored
remove hsapREF          # host genome; Apollo curates pathogens

add    someNewOrg       # approved by Uli 2026-08-21
OVERLAY

my $overlay = $O->parseString($text);

is_deeply([sort keys %{$overlay->{remove}}], ['hsapREF'], 'remove parsed');
is_deeply([sort keys %{$overlay->{add}}],    ['someNewOrg'], 'add parsed');
like($overlay->{remove}{hsapREF}, qr/host genome/, 'reason retained');
like($overlay->{add}{someNewOrg}, qr/Uli/, 'approver retained');

eval { $O->parseString("bogus hsapREF # what\n") };
like($@, qr/unknown directive 'bogus'/, 'unknown directive rejected');

# Both offending lines are named.  Finding the other occurrence by hand in a
# file being edited under time pressure is exactly the cost this avoids.
eval { $O->parseString("# header\nadd hsapREF # x\n\nremove hsapREF # y\n") };
like($@, qr/hsapREF already appears as 'add' on line 2; line 4 lists it as 'remove'.*cannot be both/,
     'contradictory entry rejected, citing both lines');

eval { $O->parseString("add\n") };
like($@, qr/missing organism/, 'malformed line rejected');

# --- parse-failure branches --------------------------------------------
#
# The fallback used to claim "needs a reason" for every unparseable line,
# including lines that plainly had one.  Each branch below is a defect the
# message can identify; anything else gets a defect-agnostic message rather
# than a confident wrong one.

eval { $O->parseString("add # approved by Uli\n") };
like($@, qr/missing organism/, 'a reason with no organism is reported as a missing organism');
unlike($@, qr/reason/, '... and does not claim the reason is missing, because it is not');

eval { $O->parseString("remove hsapREF\n") };
like($@, qr/every entry needs a '# reason'/, 'an entry with no reason at all is reported as such');

eval { $O->parseString("add someOrg extra # approved by Uli\n") };
like($@, qr/could not parse .* as '<directive> <abbrev> # <reason>'/,
     'a stray third token gets the defect-agnostic message, not a wrong diagnosis');

# --- other gaps considered in review -----------------------------------

# BEHAVIOUR CHANGE (deliberate): the same organism repeated with the SAME
# directive used to let the second line silently overwrite the first, throwing
# away one of the two reasons.  This file's only job is to record provenance,
# so silently discarding a reason is exactly the failure mode it exists to
# prevent -- and two lines for one organism means two people wrote down two
# different justifications, which a human must reconcile.  Now a hard error.
eval { $O->parseString("remove hsapREF # host genome\nremove hsapREF # not loaded here\n") };
like($@, qr/hsapREF already appears as 'remove' on line 1; merge the reason from line 2/,
     'duplicate same-directive entry rejected, citing both lines');

# BEHAVIOUR CHANGE (deliberate): the reason group was `(.+?)` with `\s*` on
# both sides, which happily matched an empty string -- "add x #   " parsed and
# stored an empty reason.  A blank reason satisfies the syntax while defeating
# the point, so the group now requires a leading non-space character.
eval { $O->parseString("add someOrg #   \n") };
like($@, qr/needs a non-empty '# reason'/, 'whitespace-only reason rejected');

# A '#' is ordinary text once the reason has started -- ticket refs and
# "issue #123" style provenance are exactly what people will write, and
# truncating the reason at the second '#' would quietly drop the useful half.
my $hashy = $O->parseString("add someOrg # approved by Uli, see ticket #4412 # dup marker\n");
is($hashy->{add}{someOrg}, 'approved by Uli, see ticket #4412 # dup marker',
   'a # inside the reason is kept verbatim, not treated as a second comment');

# This file is edited on Macs and Windows.  Both of these already parse, but
# only because the trailing `\s*` happens to absorb the `\r` and `\s` happens
# to cover tabs -- pin them so a future regex edit cannot silently break a
# whole platform's worth of edits.
my $crlf = $O->parseString("remove hsapREF # host genome\r\nadd someOrg # approved\r\n");
is(join('|', $crlf->{remove}{hsapREF}, $crlf->{add}{someOrg}), 'host genome|approved',
   'CRLF line endings parse, with no stray carriage return in the reason');

my $tabs = $O->parseString("remove\thsapREF\t# host genome\n");
is($tabs->{remove}{hsapREF}, 'host genome', 'tab-delimited lines parse');

# The overlay path is passed in by a caller, so a typo or a missed `bld` is the
# likely failure.  Pin that the error names the path and the file's role rather
# than dying somewhere later on an undef.
eval { $O->parseFile("/nonexistent/apollo/roster-overlay.txt") };
like($@, qr{^Cannot read roster overlay /nonexistent/apollo/roster-overlay\.txt: [^\n]+\n$},
     'a missing overlay file gives an actionable error naming the path, with no perl line noise');

# Parsing the real shipped file is the only test that can catch a seeded line
# that stopped being parseable.  Read it from the REPO, not from GUS_HOME: it
# is a plain data file copied verbatim by the build, so nothing is lost, and
# reading the installed copy would make this the one test that needs a prior
# `bld` -- and a stale artifact in a shared GUS_HOME would pass misleadingly.
my $shipped = $O->parseFile("$FindBin::Bin/../data/apollo/roster-overlay.txt");
is(join('/', scalar(keys %{$shipped->{remove}}), scalar(keys %{$shipped->{add}}),
        ($shipped->{remove}{hcapNAm1} ? 'suppressed' : 'candidate'),
        ($shipped->{add}{hcapNAm1}    ? 'forced'     : 'candidate')),
   '13/0/candidate/candidate',
   'the shipped overlay parses: 13 removes, 0 adds, hcapNAm1 neither suppressed nor force-added');
