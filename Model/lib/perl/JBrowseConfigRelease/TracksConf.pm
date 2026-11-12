package ApiCommonModel::Model::JBrowseConfigRelease::TracksConf;

use strict;
use warnings;

use JSON;

use ApiCommonModel::Model::JBrowseConfigRelease::Validate;

# Translates an organism's static JBrowse 1 tracks.conf (the dataset-injected
# $GUS_HOME/lib/jbrowse/auto_generated/<internal>/tracks.conf JBrowse 1 includes) into
# v5 hub tracks. Pure: the caller reads the file.

my $VALIDATE = 'ApiCommonModel::Model::JBrowseConfigRelease::Validate';

# storeClass -> v5 shape. REST is a live database query with no v5 adapter: skipped, reported.
our %STORE_CLASSES = (
  'JBrowse/Store/SeqFeature/GFF3Tabix'      => 'gff3tabix',
  'JBrowse/Store/SeqFeature/BEDTabix'       => 'bedtabix',
  'JBrowse/Store/SeqFeature/BigBed'         => 'bigbed',
  'JBrowse/Store/SeqFeature/BigWig'         => 'bigwig',
  'MultiBigWig/Store/SeqFeature/MultiBigWig' => 'multibigwig',
  'JBrowse/Store/SeqFeature/BAM'            => 'bam',
  'JBrowse/Store/SeqFeature/GTF'            => 'gtf',
  'JBrowse/Store/SeqFeature/REST'           => 'rest',
);

# JBrowse 1 colour callbacks with a VEuPathDBDisplay port (its README function table).
our %COLOR_CALLBACKS = (
  processedTranscriptColor => ['veupathProcessedTranscriptColor'],
  piggyBacColor            => ['veupathStrandColor', 'dodgerblue', 'mediumvioletred'],
);

# Covered by veupathProcessedTranscriptColor when that is the fill.
our %COVERED_BY_PROCESSED = map { $_ => 1 } qw(geneTranscriptType unprocessedTranscriptColor);

our @STYLING_KEY_PATTERNS = (qr/^style\./, qr/^onClick\./, qr/^menuTemplate/, qr/^transcriptType$/,
                             qr/^noncodingType$/);

# --- PURE: parse ---

# Mirrors JBrowse 1's ConfigAdaptor/conf.js line rules, except that a line it would
# silently drop (not a section, key, array item or continuation) is an error here.
# Returns [{label, line, values => {key => value}}] in file order; `+=` values are arrays.
sub parse {
  my ($class, $text, $file) = @_;

  my (@stanzas, %byLabel, $stanza, $key, $op, $value, $valueLine);

  my $record = sub {
    return unless(defined $value);
    my $parsed = $value;
    if($parsed =~ /^json:(.+)/is) {
      my $json = $1;
      $parsed = eval { JSON->new->allow_nonref->decode($json) };
      die "$file:$valueLine: $key: json value does not parse: $@" unless(defined $parsed);
    }
    if($op eq '+=') {
      my $existing = $stanza->{values}{$key};
      $existing = defined($existing) ? (ref($existing) eq 'ARRAY' ? $existing : [$existing]) : [];
      push @$existing, $parsed;
      $parsed = $existing;
    }
    $stanza->{values}{$key} = $parsed;
    undef $value;
  };

  my $n = 0;
  foreach my $line (split(/\n/, $text, -1)) {
    $n++;
    $line =~ s/\r$//;
    $line = '' if($line =~ /^\s*#/);

    if($line =~ /^\s*\[([^\]]+)/) {
      $record->();
      undef $key;
      my $head = $1;
      $head =~ s/^\s+|\s+$//g;
      die "$file:$n: section [$head] is not a [tracks.<label>] stanza\n"
        unless($head =~ /^tracks\s*\.\s*(.+)$/);
      my $label = $1;
      $stanza = $byLabel{$label} ||= do {
        my $new = {label => $label, line => $n, values => {}};
        push @stanzas, $new;
        $new;
      };
    }
    elsif($line =~ (defined($value) ? qr/^(\S[^+=]+)(\+?=)(.*)$/ : qr/^([^+=]+)(\+?=)(.*)$/)) {
      my ($k, $o, $v) = ($1, $2, $3);
      $record->();
      die "$file:$n: key outside a [tracks.<label>] stanza: $line\n" unless($stanza);
      ($key, $op, $value, $valueLine) = (join('.', split(/\s*\.\s*/, _trim($k))), $o, _trim($v), $n);
    }
    elsif(defined($key) && $line =~ /^\s{0,4}\+\s*(.+)$/) {
      my $v = $1;
      $record->();
      ($op, $value, $valueLine) = ('+=', _trim($v), $n);
    }
    elsif(defined($value) && $line =~ /^\s+(\S.*)$/) {
      my $more = _trim($1);
      $value .= length($value) ? " $more" : $more;
    }
    elsif($line =~ /^\s*$/) {
      $record->();
      undef $key;
    }
    else {
      die "$file:$n: not a section, key = value, array item or continuation line: $line\n";
    }
  }
  $record->();

  return \@stanzas;
}

sub _trim { my ($s) = @_; $s =~ s/^\s+|\s+$//g; return $s }

# --- PURE: translate ---

sub token {
  my ($class, $text) = @_;
  $text =~ s/\s+-\s+/_/g;
  $text =~ s/[^A-Za-z0-9_.-]+/_/g;
  $text =~ s/_{2,}/_/g;
  $text =~ s/^[_.-]+|_+$//g;
  return $text;
}

# <public abbrev>_<label>, without doubling an abbrev the label already carries.
sub trackIdFor {
  my ($class, $organism, $label) = @_;
  my $abbrev = $organism->{abbrev};
  my $internal = $organism->{internal_abbrev} || $abbrev;
  my $id = $class->token($label);
  $id =~ s/^\Q$internal\E_// if($internal ne $abbrev);
  return index($id, "${abbrev}_") == 0 ? $id : "${abbrev}_$id";
}

sub _uriLocation { return {uri => $_[0], locationType => 'UriLocation'} }

sub _plainName {
  my ($text) = @_;
  $text =~ s/<[^>]*>//g;
  $text =~ s/\s+/ /g;
  return _trim($text);
}

# ${nameForFileNames} is the only template variable the stanzas use.
sub _resolveUrl {
  my ($class, $url, $organism, $where) = @_;
  $url =~ s/\$\{nameForFileNames\}/$organism->{name_for_filenames}/g;
  die "$where: unresolved template variable in $url\n" if($url =~ /\$\{/);
  return $url;
}

sub _styling {
  my ($class, $organism, $stanza) = @_;

  my $values = $stanza->{values};
  my ($color, %mapped);
  if(defined($values->{'style.color'}) && !ref($values->{'style.color'})
     && $values->{'style.color'} =~ /^\{(\w+)\}$/ && $COLOR_CALLBACKS{$1}) {
    my ($name, @args) = @{$COLOR_CALLBACKS{$1}};
    $color = "jexl:$name(" . join(', ', 'feature', map { "'$_'" } @args) . ")";
    $mapped{'style.color'} = 1;
    if($name eq 'veupathProcessedTranscriptColor') {
      foreach my $k (keys %$values) {
        my $v = $values->{$k};
        $mapped{$k} = 1 if(defined($v) && !ref($v) && $v =~ /^\{(\w+)\}$/ && $COVERED_BY_PROCESSED{$1});
      }
    }
  }

  my @unmapped;
  foreach my $k (sort keys %$values) {
    next if($mapped{$k} || !grep { $k =~ $_ } @STYLING_KEY_PATTERNS);
    my $text = ref($values->{$k}) ? JSON->new->canonical->encode($values->{$k}) : $values->{$k};
    next unless($text =~ /\{\w+\}|\bfunction\s*\(/);
    push @unmapped, {organism => $organism->{abbrev}, label => $stanza->{label}, key => $k, callback => $text};
  }
  return ($color, \@unmapped);
}

# Paths this track reads, for the caller's mirror check.
sub _locationUris {
  my ($adapter) = @_;
  my @uris;
  foreach my $k (sort keys %$adapter) {
    my $v = $adapter->{$k};
    if(ref($v) eq 'HASH') {
      push @uris, $v->{uri} if(defined $v->{uri});
      push @uris, _locationUris($v);
    }
    elsif(ref($v) eq 'ARRAY') {
      push @uris, _locationUris($_) foreach(grep { ref($_) eq 'HASH' } @$v);
    }
  }
  return @uris;
}

sub _adapter {
  my ($class, $kind, $stanza, $organism, $where) = @_;

  my $values = $stanza->{values};
  if($kind eq 'multibigwig') {
    my $sources = $values->{urlTemplates};
    $sources = [$sources] if(ref($sources) eq 'HASH');
    die "$where: MultiBigWig has no urlTemplates\n" unless(ref($sources) eq 'ARRAY' && @$sources);
    my @subadapters;
    foreach my $source (@$sources) {
      die "$where: a MultiBigWig urlTemplates entry is not {url, name}\n"
        unless(ref($source) eq 'HASH' && defined($source->{url}) && defined($source->{name}));
      push @subadapters, {type => 'BigWigAdapter', name => $source->{name},
                          (defined($source->{color}) ? (color => $source->{color}) : ()),
                          bigWigLocation => _uriLocation($class->_resolveUrl($source->{url}, $organism, $where))};
    }
    return {type => 'MultiWiggleAdapter', subadapters => \@subadapters};
  }

  my $url = $values->{urlTemplate};
  die "$where: no urlTemplate\n" unless(defined($url) && !ref($url) && length($url));
  $url = $class->_resolveUrl($url, $organism, $where);

  my $index = sub {
    my ($suffix) = @_;
    my $explicit = $values->{indexUrlTemplate} // $values->{tbiUrlTemplate};
    return {location => _uriLocation(defined($explicit) ? $class->_resolveUrl($explicit, $organism, $where) : "$url$suffix")};
  };

  return {type => 'Gff3TabixAdapter', gffGzLocation => _uriLocation($url), index => $index->('.tbi')}
    if($kind eq 'gff3tabix');
  return {type => 'BedTabixAdapter', bedGzLocation => _uriLocation($url), index => $index->('.tbi')}
    if($kind eq 'bedtabix');
  return {type => 'BigBedAdapter', bigBedLocation => _uriLocation($url)} if($kind eq 'bigbed');
  return {type => 'BigWigAdapter', bigWigLocation => _uriLocation($url)} if($kind eq 'bigwig');
  return {type => 'BamAdapter', bamLocation => _uriLocation($url), index => $index->('.bai')} if($kind eq 'bam');
  return {type => 'GtfAdapter', gtfLocation => _uriLocation($url)} if($kind eq 'gtf');
  die "$where: no adapter for $kind\n";
}

our %SHAPES = (
  gff3tabix   => ['FeatureTrack',           'LinearBasicDisplay'],
  bedtabix    => ['FeatureTrack',           'LinearBasicDisplay'],
  bigbed      => ['FeatureTrack',           'LinearBasicDisplay'],
  gtf         => ['FeatureTrack',           'LinearBasicDisplay'],
  bigwig      => ['QuantitativeTrack',      'LinearWiggleDisplay'],
  multibigwig => ['MultiQuantitativeTrack', 'LinearWiggleDisplay'],
  bam         => ['AlignmentsTrack',        'LinearAlignmentsDisplay'],
);

our @METADATA_KEYS = qw(description dataset trackType attribution strand alignment);

# $organism: {abbrev, internal_abbrev, name_for_filenames}. $file names the source in errors.
# Returns {tracks, report => {stanzas, emitted => {kind => n}, rest => [labels], unmapped => [...]},
#          uris => [every location a track reads]}.
sub translate {
  my ($class, $organism, $stanzas, $file) = @_;

  my (@tracks, %emitted, @rest, @unmapped, @uris);
  foreach my $stanza (@$stanzas) {
    my $label = $stanza->{label};
    my $where = "$file:$stanza->{line}: $organism->{abbrev} [tracks.$label]";
    my $storeClass = $stanza->{values}{storeClass};
    die "$where: no storeClass\n" unless(defined($storeClass) && !ref($storeClass));

    my $kind = $STORE_CLASSES{$storeClass};
    die "$organism->{abbrev}: tracks.$label: storeClass $storeClass has no v5 mapping ($file:$stanza->{line})\n"
      unless($kind);
    if($kind eq 'rest') {
      push @rest, $label;
      next;
    }

    my $values = $stanza->{values};
    my ($trackType, $displayType) = @{$SHAPES{$kind}};
    my $trackId = $class->trackIdFor($organism, $label);
    my @category = grep { defined($_) && length($_) } map { ref($_) ? undef : $_ }
                   ($values->{category}, $values->{'metadata.subcategory'});

    my $adapter = $class->_adapter($kind, $stanza, $organism, $where);
    my $display = {type => $displayType, displayId => "$trackId-$displayType"};
    if($kind eq 'multibigwig') {
      $display->{mark} = 'bar';
      $display->{rows} = 'source';
    }

    my ($color, $styling) = $class->_styling($organism, $stanza);
    $display->{encoding}{color}{value} = $color if(defined($color) && $displayType eq 'LinearBasicDisplay');
    push @unmapped, @$styling;

    my %metadata = map { ($_ => $values->{"metadata.$_"}) }
                   grep { defined($values->{"metadata.$_"}) && !ref($values->{"metadata.$_"}) } @METADATA_KEYS;

    my $name = defined($values->{key}) && !ref($values->{key}) ? _plainName($values->{key}) : $label;
    push @tracks, {type => $trackType, trackId => $trackId, name => (length($name) ? $name : $label),
                   (@category ? (category => \@category) : ()),
                   assemblyNames => [$organism->{abbrev}],
                   adapter => $adapter, displays => [$display],
                   (%metadata ? (metadata => \%metadata) : ())};
    push @uris, map { {trackId => $trackId, kind => $kind, uri => $_} } _locationUris($adapter);
    $emitted{$kind}++;
  }

  return {tracks => \@tracks, uris => \@uris,
          report => {stanzas => scalar(@$stanzas), emitted => \%emitted, rest => \@rest, unmapped => \@unmapped}};
}

1;
