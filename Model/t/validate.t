use strict;
use warnings;
use Test::More;
use JSON;
use File::Temp qw(tempdir);
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JBrowseConfigRelease::Validate;

my $V = 'ApiCommonModel::Model::JBrowseConfigRelease::Validate';
my $S = '/a/service/jbrowse/store?data=';

sub loc { return {uri => $S . $_[0], locationType => 'UriLocation'} }

sub validConfig {
  return {
    assemblies => [{
      name => 'pfal3D7',
      sequence => {
        type => 'ReferenceSequenceTrack', trackId => 'pfal3D7_refseq',
        adapter => {type => 'IndexedFastaAdapter',
                    fastaLocation => loc('Pf/genome.fasta'), faiLocation => loc('Pf/genome.fasta.fai')},
      },
    }],
    tracks => [
      {type => 'QuantitativeTrack', trackId => 'pfal3D7_ds1_cov', assemblyNames => ['pfal3D7'],
       adapter => {type => 'BigWigAdapter', bigWigLocation => loc('Pf/a.bw')},
       displays => [{type => 'LinearWiggleDisplay', displayId => 'pfal3D7_ds1_cov-LinearWiggleDisplay'}]},
      {type => 'MultiQuantitativeTrack', trackId => 'pfal3D7_ds2_unique', assemblyNames => ['pfal3D7'],
       adapter => {type => 'MultiWiggleAdapter', subadapters => [
         {type => 'BigWigAdapter', name => 's1', bigWigLocation => loc('Pf/s1.bw')}]},
       displays => [{type => 'MultiLinearWiggleDisplay',
                     displayId => 'pfal3D7_ds2_unique-MultiLinearWiggleDisplay'}]},
      {type => 'VariantTrack', trackId => 'pfal3D7_dnaseq_merged_short_variants', assemblyNames => ['pfal3D7'],
       adapter => {type => 'VcfTabixAdapter', vcfGzLocation => loc('Pf/v.vcf.gz'),
                   index => {location => loc('Pf/v.vcf.gz.tbi')}},
       displays => []},
      {type => 'FeatureTrack', trackId => 'pfal3D7_centromere', assemblyNames => ['pfal3D7'],
       adapter => {type => 'Gff3TabixAdapter',
                   gffGzLocation => {uri => '/a/service/jbrowse/auxiliary?data=c.gff.gz'},
                   index => {location => {uri => '/a/service/jbrowse/auxiliary?data=c.gff.gz.tbi'}}},
       displays => [{type => 'LinearBasicDisplay', displayId => 'pfal3D7_centromere-LinearBasicDisplay'}]},
    ],
  };
}

sub rulesFor {
  my ($config) = @_;
  return [map { $_->{rule} } @{$V->validate($config)}];
}

sub violates {
  my ($mutate, $rule, $name) = @_;
  my $config = validConfig();
  $mutate->($config);
  my $rules = rulesFor($config);
  ok((grep { $_ eq $rule } @$rules), "$rule: $name") or diag explain $rules;
}

# --- a conforming config is clean ---
is_deeply($V->validate(validConfig()), [], 'a config meeting the contract has no violations');

# --- one failing case per rule ---
violates(sub { $_[0]{tracks}[0]{storeClass} = 'JBrowse/Store/SeqFeature/BigWig' },
         'jbrowse1-shape', 'storeClass is a JBrowse 1 key');
violates(sub { $_[0]{tracks}[0]{urlTemplate} = '/a/x' }, 'jbrowse1-shape', 'urlTemplate is a JBrowse 1 key');
violates(sub { delete $_[0]{tracks}[0]{trackId} }, 'track-id-missing', 'no trackId');
violates(sub { $_[0]{tracks}[0]{trackId} = 'pfal3D7_Duffy - Unique' }, 'track-id-format', 'spaces');
violates(sub { $_[0]{tracks}[0]{trackId} = 'pfal3D7_a,b' }, 'track-id-format', 'commas');
violates(sub { $_[0]{tracks}[0]{trackId} = '_pfal3D7_a' }, 'track-id-format', 'leading underscore');
violates(sub { $_[0]{tracks}[1]{trackId} = 'pfal3D7_ds1_cov' }, 'track-id-duplicate', 'two tracks share an id');
violates(sub { $_[0]{tracks}[0]{trackId} = 'Centromere' }, 'track-id-prefix', 'no <abbrev>_ prefix');
violates(sub { $_[0]{tracks}[0]{type} = undef }, 'track-type', 'type null');
violates(sub { $_[0]{tracks}[0]{type} = 'MultiBigWig/View/Track/MultiWiggle/MultiXYPlot' },
         'track-type', 'JBrowse 1 class name as type');
violates(sub { $_[0]{tracks}[0]{assemblyNames} = [undef] }, 'assembly-names', '[null]');
violates(sub { delete $_[0]{tracks}[0]{assemblyNames} }, 'assembly-names', 'missing');
violates(sub { $_[0]{tracks}[0]{assemblyNames} = ['pfalIT'] }, 'assembly-names', 'undeclared assembly');
violates(sub { $_[0]{tracks}[0]{displays}[0]{type} = 'NeatCanvasFeatures/View/Track/NeatFeatures' },
         'display-type', 'JBrowse 1 display class');
violates(sub { $_[0]{tracks}[0]{displays}[0]{displayId} = 'wiggle_X=HASH(0x563d27e80a98)' },
         'display-id', 'Perl object address');
violates(sub { delete $_[0]{tracks}[0]{displays}[0]{displayId} }, 'display-id', 'missing displayId');
violates(sub { $_[0]{tracks}[0]{adapter}{type} = 'IndexedFasta' }, 'adapter-type', 'not a v5 adapter name');
violates(sub { delete $_[0]{tracks}[0]{adapter} }, 'adapter-type', 'no adapter');
violates(sub { $_[0]{tracks}[1]{adapter}{subadapters}[0]{type} = 'BigWig' },
         'adapter-type', 'subadapters are checked too');
violates(sub { delete $_[0]{tracks}[0]{adapter}{bigWigLocation} }, 'adapter-location', 'bigwig with no file');
violates(sub { delete $_[0]{tracks}[2]{adapter}{index} }, 'adapter-location', 'tabix with no index');
violates(sub { delete $_[0]{assemblies}[0]{sequence}{adapter}{faiLocation} },
         'adapter-location', 'indexed fasta with no fai');
violates(sub { $_[0]{tracks}[1]{adapter}{subadapters} = [] }, 'adapter-location', 'multi with no subadapters');
violates(sub { $_[0]{tracks}[0]{adapter}{bigWigLocation}{uri} = 'PlasmoDB/build-71/Pf/a.bw' },
         'location-url', 'relative build path');
violates(sub { $_[0]{tracks}[2]{adapter}{index}{location}{uri} = 'https://plasmodb.org/a/x.tbi' },
         'location-url', 'absolute URL in an index');
violates(sub { $_[0]{tracks}[1]{adapter}{subadapters}[0]{bigWigLocation}{uri} = 'x.bw' },
         'location-url', 'subadapter location');
violates(sub { $_[0]{assemblies}[0]{sequence}{adapter}{fastaLocation}{uri} = 'PlasmoDB/build-71/g.fa' },
         'location-url', 'assembly location');
violates(sub { $_[0]{assemblies}[0]{name} = 'Plasmodium falciparum 3D7' }, 'assembly-name', 'spaces in name');

# --- every violation names where it is ---
{
  my $config = validConfig();
  $config->{tracks}[0]{type} = undef;
  my ($v) = @{$V->validate($config)};
  is($v->{where}, 'tracks[0] pfal3D7_ds1_cov', 'where names the index and trackId');
  like($v->{message}, qr/undef/, 'message shows the offending value');
}

# --- all violations, not the first ---
{
  my $config = validConfig();
  $config->{tracks}[0]{type} = undef;
  $config->{tracks}[1]{type} = undef;
  $config->{tracks}[0]{trackId} = 'a b';
  is(scalar(@{$V->validate($config)}), 5, 'every violation is returned (incl. the display-id it implies)');
  is_deeply($V->countByRule($V->validate($config)),
            {'track-type' => 2, 'track-id-format' => 1, 'track-id-prefix' => 1, 'display-id' => 1},
            'counts by rule')
    or diag explain $V->validate($config);
}

# --- every documented rule is exercised above ---
is_deeply([sort @ApiCommonModel::Model::JBrowseConfigRelease::Validate::RULES],
          [sort qw(jbrowse1-shape track-id-missing track-id-format track-id-duplicate track-id-prefix
                   track-type assembly-names display-type display-id adapter-type adapter-location
                   location-url assembly-name)],
          'the rule list is the one this file covers');

# --- the CLI ---
{
  my $script = "$ENV{GUS_HOME}/bin/validateJBrowseConfig";
  ok(-x $script, 'validateJBrowseConfig is installed');

  my $dir = tempdir(CLEANUP => 1);
  my $write = sub {
    my ($name, $config) = @_;
    open(my $fh, '>', "$dir/$name") or die $!;
    print $fh encode_json($config);
    close $fh;
    return "$dir/$name";
  };

  my $good = $write->('good.json', validConfig());
  my $bad = validConfig();
  $bad->{tracks}[0]{type} = undef;
  $bad = $write->('bad.json', $bad);

  my $out = `$script $good 2>&1`;
  is($? >> 8, 0, 'exits 0 on a clean config');
  like($out, qr/violations: 0/, 'and says so');

  $out = `$script $bad 2>/dev/null`;
  is($? >> 8, 1, 'exits 1 on violations');
  like($out, qr/^track-type\ttracks\[0\] pfal3D7_ds1_cov\t/m, 'one tab-separated line per violation');

  `$script 2>/dev/null`;
  is($? >> 8, 2, 'exits 2 with no file');
  `$script $dir/missing.json 2>/dev/null`;
  is($? >> 8, 2, 'exits 2 on an unreadable file');
}

done_testing();
