package ApiCommonModel::Model::JBrowseConfigRelease::Validate;

use strict;
use warnings;

# Checks a decoded JBrowse 2 v5 config against the VEuPathDB track contract
# (decision 0007). Pure: no database, no filesystem. Returns every violation
# rather than stopping at the first, so one run is the whole to-do list.

our $TRACK_ID_PATTERN = qr/^[A-Za-z0-9][A-Za-z0-9_.-]*$/;
our @STORE_PREFIXES = ('/a/service/jbrowse/store?data=', '/a/service/jbrowse/auxiliary?data=');

our %TRACK_TYPES = map { $_ => 1 } qw(
  FeatureTrack QuantitativeTrack MultiQuantitativeTrack VariantTrack
  AlignmentsTrack ReferenceSequenceTrack
);

our %DISPLAY_TYPES = map { $_ => 1 } qw(
  LinearBasicDisplay LinearWiggleDisplay
  LinearVariantDisplay LinearMarkDisplay LinearAlignmentsDisplay
  LinearReferenceSequenceDisplay
);

our %ADAPTER_TYPES = map { $_ => 1 } qw(
  BigWigAdapter MultiWiggleAdapter Gff3TabixAdapter BedTabixAdapter
  VcfTabixAdapter BamAdapter IndexedFastaAdapter
);

# The location slots an adapter cannot load without.
our %REQUIRED_LOCATIONS = (
  BigWigAdapter       => [['bigWigLocation']],
  Gff3TabixAdapter    => [['gffGzLocation'], ['index', 'location']],
  BedTabixAdapter     => [['bedGzLocation'], ['index', 'location']],
  VcfTabixAdapter     => [['vcfGzLocation'], ['index', 'location']],
  BamAdapter          => [['bamLocation'],   ['index', 'location']],
  IndexedFastaAdapter => [['fastaLocation'], ['faiLocation']],
  MultiWiggleAdapter  => [['subadapters']],
);

# The VEuPathDBDisplay plugin's jexl functions: its README function table, the contract
# producers code against. A hub's jexl is exactly one call to one of these.
our %JEXL_FUNCTIONS = map { $_ => 1 } qw(
  veupathVariantEffectColor veupathStrandColor veupathProcessedTranscriptColor
  veupathGsnapIntronColor veupathGsnapIntronLineThickness veupathHaplotypeColor
  veupathBindingSiteColor veupathInterproColor veupathSignalpColor veupathIedbColor
  veupathPostTranslationalModColor
);

our $JEXL_LITERAL = qr/'[^'\\]*'|-?\d+(?:\.\d+)?/;
our $JEXL_CALL = qr/^jexl:(\w+)\(\s*feature\s*((?:,\s*(?:$JEXL_LITERAL)\s*)*)\)$/;

# Attribute references a jexl string could make. The v5 GFF3 adapter lowercases attribute
# names, so an uppercase one never matches a field (F1).
our @JEXL_ATTRIBUTE_REFS = (
  qr/\bfeature\s*\.\s*([A-Za-z_]\w*)\b(?!\s*\()/,
  qr/\bget\s*\(\s*feature\s*,\s*'([^']*)'/,
  qr/\bfeature\s*\.\s*get\s*\(\s*'([^']*)'/,
);

our @RULES = qw(
  jbrowse1-shape track-id-missing track-id-format track-id-duplicate track-id-prefix
  track-type assembly-names display-type display-id adapter-type adapter-location
  location-url assembly-name jexl-call jexl-attribute-case
);

# $opts->{locationPrefixes}: further accepted location prefixes, beyond the store URLs.
sub validate {
  my ($class, $config, $opts) = @_;

  my @prefixes = (@STORE_PREFIXES, @{($opts || {})->{locationPrefixes} || []});

  my @violations;
  my $add = sub {
    my ($rule, $where, $message) = @_;
    push @violations, {rule => $rule, where => $where, message => $message};
  };

  my %assemblyNames;
  my $assemblies = ref($config->{assemblies}) eq 'ARRAY' ? $config->{assemblies} : [];
  foreach my $i (0 .. $#$assemblies) {
    my $assembly = $assemblies->[$i];
    my $name = $assembly->{name};
    my $where = "assemblies[$i]" . (defined($name) ? " $name" : '');

    if(!defined($name) || $name !~ $TRACK_ID_PATTERN) {
      $add->('assembly-name', $where, 'assembly name missing or not an abbrev: ' . _show($name));
    }
    else {
      $assemblyNames{$name} = 1;
    }

    my $adapter = ref($assembly->{sequence}) eq 'HASH' ? $assembly->{sequence}{adapter} : undef;
    $class->_checkAdapter($adapter, $where, $add, \@prefixes);
  }

  my %seen;
  my $tracks = ref($config->{tracks}) eq 'ARRAY' ? $config->{tracks} : [];
  foreach my $i (0 .. $#$tracks) {
    my $track = $tracks->[$i];
    my $trackId = ref($track) eq 'HASH' ? $track->{trackId} : undef;
    my $where = "tracks[$i]" . (defined($trackId) ? " $trackId" : '');

    unless(ref($track) eq 'HASH') {
      $add->('track-id-missing', $where, 'track is not an object: ' . _show($track));
      next;
    }

    my @jbrowse1Keys = grep { exists($track->{$_}) } qw(storeClass urlTemplate urlTemplates);
    $add->('jbrowse1-shape', $where, 'JBrowse 1 keys present: ' . join(', ', @jbrowse1Keys))
      if(@jbrowse1Keys);

    if(!defined($trackId) || $trackId eq '') {
      $add->('track-id-missing', $where, 'no trackId');
    }
    else {
      $add->('track-id-format', $where, "trackId does not match $TRACK_ID_PATTERN")
        unless($trackId =~ $TRACK_ID_PATTERN);
      $add->('track-id-duplicate', $where, 'trackId already used by ' . $seen{$trackId})
        if($seen{$trackId});
      $seen{$trackId} ||= "tracks[$i]";
    }

    my $type = $track->{type};
    $add->('track-type', $where, 'track type not in the v5 allowlist: ' . _show($type))
      unless(defined($type) && $TRACK_TYPES{$type});

    my $names = $track->{assemblyNames};
    my @names = ref($names) eq 'ARRAY' ? @$names : ();
    if(!@names || grep { !defined($_) || !$assemblyNames{$_} } @names) {
      $add->('assembly-names', $where,
             'assemblyNames must name a declared assembly: ' . _show($names));
    }
    elsif(defined($trackId) && !grep { index($trackId, "${_}_") == 0 } @names) {
      $add->('track-id-prefix', $where, "trackId does not start with <abbrev>_ ($names[0]_)");
    }

    my $displays = ref($track->{displays}) eq 'ARRAY' ? $track->{displays} : [];
    foreach my $d (0 .. $#$displays) {
      my $display = $displays->[$d];
      my $displayType = ref($display) eq 'HASH' ? $display->{type} : undef;
      my $dwhere = "$where displays[$d]";

      $add->('display-type', $dwhere, 'display type not in the v5 allowlist: ' . _show($displayType))
        unless(defined($displayType) && $DISPLAY_TYPES{$displayType});

      next unless(defined($trackId) && defined($displayType));
      my $expected = "${trackId}-$displayType";
      $add->('display-id', $dwhere, 'displayId ' . _show($display->{displayId}) . " is not $expected")
        unless(defined($display->{displayId}) && $display->{displayId} eq $expected);
    }

    $class->_checkAdapter($track->{adapter}, $where, $add, \@prefixes);
    $class->_checkJexl($track, $where, $add);
  }

  return \@violations;
}

sub _checkJexl {
  my ($class, $track, $where, $add) = @_;

  foreach my $found (_jexlStrings($track, '')) {
    my ($path, $jexl) = @$found;
    my $jwhere = "$where $path";

    my ($name) = $jexl =~ $JEXL_CALL;
    if(!defined($name)) {
      $add->('jexl-call', $jwhere, "not a single veupath* call with literal arguments: $jexl");
    }
    elsif(!$JEXL_FUNCTIONS{$name}) {
      $add->('jexl-call', $jwhere, "function not in the VEuPathDBDisplay allowlist: $name");
    }

    foreach my $pattern (@JEXL_ATTRIBUTE_REFS) {
      while($jexl =~ /$pattern/g) {
        my $attribute = $1;
        next if($attribute eq lc($attribute));
        $add->('jexl-attribute-case', $jwhere, "attribute '$attribute' is not lowercase: $jexl");
      }
    }
  }
}

# [path, string] for every "jexl:" string under a node, in key order.
sub _jexlStrings {
  my ($node, $path) = @_;

  if(ref($node) eq 'HASH') {
    return map { _jexlStrings($node->{$_}, $path eq '' ? $_ : "$path.$_") } sort keys %$node;
  }
  if(ref($node) eq 'ARRAY') {
    return map { _jexlStrings($node->[$_], "${path}[$_]") } 0 .. $#$node;
  }
  return defined($node) && !ref($node) && $node =~ /^jexl:/ ? ([$path, $node]) : ();
}

sub _checkAdapter {
  my ($class, $adapter, $where, $add, $prefixes) = @_;

  unless(ref($adapter) eq 'HASH') {
    $add->('adapter-type', $where, 'no adapter');
    return;
  }

  my $type = $adapter->{type};
  $add->('adapter-type', $where, 'adapter type not in the v5 allowlist: ' . _show($type))
    unless(defined($type) && $ADAPTER_TYPES{$type});

  foreach my $path (@{$REQUIRED_LOCATIONS{$type || ''} || []}) {
    my $value = $adapter;
    $value = ref($value) eq 'HASH' ? $value->{$_} : undef foreach(@$path);
    $add->('adapter-location', $where, "$type has no " . join('.', @$path))
      unless(defined($value) && (ref($value) ne 'ARRAY' || @$value));
  }

  foreach my $uri (_locationUris($adapter)) {
    next if(grep { index($uri, $_) == 0 } @$prefixes);
    $add->('location-url', $where, "location is not a site-relative store URL: $uri");
  }

  foreach my $sub (@{ref($adapter->{subadapters}) eq 'ARRAY' ? $adapter->{subadapters} : []}) {
    $class->_checkAdapter($sub, "$where subadapter " . _show(ref($sub) eq 'HASH' ? $sub->{name} : undef), $add, $prefixes);
  }
}

# Every {uri} under an adapter, not descending into subadapters (checked on their own).
sub _locationUris {
  my ($node) = @_;

  my @uris;
  if(ref($node) eq 'HASH') {
    push @uris, $node->{uri} if(defined($node->{uri}) && !ref($node->{uri}));
    foreach my $key (sort keys %$node) {
      next if($key eq 'subadapters');
      push @uris, _locationUris($node->{$key}) if(ref($node->{$key}));
    }
  }
  elsif(ref($node) eq 'ARRAY') {
    push @uris, _locationUris($_) foreach(@$node);
  }
  return @uris;
}

sub countByRule {
  my ($class, $violations) = @_;

  my %counts;
  $counts{$_->{rule}}++ foreach(@$violations);
  return \%counts;
}

sub _show {
  my ($value) = @_;
  return 'undef' unless(defined($value));
  return "'$value'" unless(ref($value));
  return ref($value) eq 'ARRAY'
    ? '[' . join(', ', map { _show($_) } @$value) . ']'
    : ref($value);
}

1;
