use strict;
use warnings;
use Test::More tests => 12;
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

eval { $O->parseString("add hsapREF # x\nremove hsapREF # y\n") };
like($@, qr/both add and remove/, 'contradictory entry rejected');

eval { $O->parseString("add\n") };
like($@, qr/missing organism/, 'malformed line rejected');

# --- gaps considered in review -----------------------------------------

# BEHAVIOUR CHANGE (deliberate): the same organism repeated with the SAME
# directive used to let the second line silently overwrite the first, throwing
# away one of the two reasons.  This file's only job is to record provenance,
# so silently discarding a reason is exactly the failure mode it exists to
# prevent -- and two lines for one organism means two people wrote down two
# different justifications, which a human must reconcile.  Now a hard error.
eval { $O->parseString("remove hsapREF # host genome\nremove hsapREF # not loaded here\n") };
like($@, qr/more than once/, 'duplicate same-directive entry rejected, not silently merged');

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

# The overlay path is passed in by a caller, so a typo or a missed `bld` is the
# likely failure.  Pin that the error names the path and the file's role rather
# than dying somewhere later on an undef.
eval { $O->parseFile("/nonexistent/apollo/roster-overlay.txt") };
like($@, qr{Cannot read roster overlay /nonexistent/apollo/roster-overlay\.txt},
     'a missing overlay file gives an actionable error naming the path');

# Parsing the real shipped file is the only test that can catch a seeded line
# that stopped being parseable; it also pins that hcapNAm1 stays an add
# candidate rather than being quietly suppressed.
my $shipped = $O->parseFile($ENV{GUS_HOME} . "/data/ApiCommonModel/Model/apollo/roster-overlay.txt");
is(join('/', scalar(keys %{$shipped->{remove}}), scalar(keys %{$shipped->{add}}),
        ($shipped->{remove}{hcapNAm1} ? 'suppressed' : 'candidate')),
   '13/0/candidate',
   'the shipped overlay parses: 13 removes, 0 adds, hcapNAm1 left as an add candidate');
