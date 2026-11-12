use strict;
use warnings;
use Test::More;
use JSON;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::JBrowseConfigRelease::TracksConf;
use ApiCommonModel::Model::JBrowseConfigRelease::Validate;

my $T = 'ApiCommonModel::Model::JBrowseConfigRelease::TracksConf';
my $V = 'ApiCommonModel::Model::JBrowseConfigRelease::Validate';
my $S = '/a/service/jbrowse/store?data=';
my $X = '/a/service/jbrowse/auxiliary?data=';

my $ORG = {abbrev => 'pfal3D7', internal_abbrev => 'pfal3D7', name_for_filenames => 'Pfalciparum3D7'};

sub translate {
  my ($text, $organism) = @_;
  return $T->translate($organism || $ORG, $T->parse($text, 'tracks.conf'), 'tracks.conf');
}

sub byId { my ($result) = @_; return {map { $_->{trackId} => $_ } @{$result->{tracks}}} }

# The store classes the files use, one stanza each, in the shapes the files write them.
my $ALL = <<"CONF";
# THIS FILE SHOULD ONLY CONTAIN TEMPLATE ANCHORS

# TEMPLATE_ANCHOR jbrowseCommon
[tracks.gcContent]
storeClass=JBrowse/Store/SeqFeature/REST
category=Sequence Analysis
baseUrl=/a/service/jbrowse
query.feature=ReferenceSequence
key=GC Content

[tracks.pfal3D7_UTRs]
category=Gene Models
metadata.subcategory=Transcripts
metadata.trackType=Segments
storeClass=JBrowse/Store/SeqFeature/GFF3Tabix
urlTemplate=${S}\${nameForFileNames}/prealigned/gff/utrs.gff.gz
style.color={processedTranscriptColor}
key          = UTRs for <i>P. falciparum</i> 3D7
metadata.dataset=UTRs
fmtMetaValue_Dataset=function() { return datasetLinkByDatasetName("x", "y"); }

[tracks.AnidTSS]
category=Gene Models
key=Transcription start sites
storeClass=JBrowse/Store/SeqFeature/BEDTabix
urlTemplate=${S}AnidulansFGSCA4/genomeBrowser/bed/sibthorpTSS.bed.gz
style.color=function(feature) { return feature.get('strand') == -1 ? 'red' : 'blue'; }

[tracks.TSS_curated]
storeClass=JBrowse/Store/SeqFeature/BigBed
urlTemplate=${X}ToxoDB/tgonME49/tss.bigBed
key=Predicted TSSs
category=Gene Models

[tracks.HP1_ring]
storeClass=JBrowse/Store/SeqFeature/BigWig
urlTemplate=${X}PlasmoDB/pfal3D7_HP1/Pf3D7_ring_ratio.bw
key=HP1 ring
category=Epigenomics
metadata.subcategory=ChIP-Seq

[tracks.siegelTSS]
storeClass=MultiBigWig/Store/SeqFeature/MultiBigWig
urlTemplates+=json:{"url":"${X}TriTrypDB/siegelTSS/fwd.bw", "name": "TSS fwd", "color": "blue"}
urlTemplates+=json:{"url":"${X}TriTrypDB/siegelTSS/rev.bw", "name": "TSS rev", "color": "red"}
key=TSS
category=Gene Models

[tracks.MicroarrayProbes_Affy]
category=Sequence Analysis
key=Microarray Probes Affymetrix
storeClass=JBrowse/Store/SeqFeature/BAM
urlTemplate=${S}\${nameForFileNames}/microarrayPlatform/bam/Affy/probes.bam
indexUrlTemplate=${S}\${nameForFileNames}/microarrayPlatform/bam/Affy/probes.bam.bai
onClick.content=function(track, feature){ var c = track.browser.config; return c.arrayElementTitle(track, feature, "Expression")}
menuTemplate+=json:{"label": "View Details", "content": "{sequenceTitleFxn}"}

[tracks.acasNeff2021-ACANB_genome_annotation]
category=Gene Models
key=ACANB genome annotation
storeClass=JBrowse/Store/SeqFeature/GTF
urlTemplate=${X}AmoebaDB/AcastellaniiNeff2021/ACANB.gtf
style.color={alternateTranscriptColor}
style.borderColor={processedTranscriptBorderColor}
CONF

# --- each store class ---
{
  my $result = translate($ALL);
  my $t = byId($result);

  is_deeply([sort keys %$t],
            [qw(pfal3D7_AnidTSS pfal3D7_HP1_ring pfal3D7_MicroarrayProbes_Affy pfal3D7_TSS_curated
                pfal3D7_UTRs pfal3D7_acasNeff2021-ACANB_genome_annotation pfal3D7_siegelTSS)],
            'every non-REST stanza becomes one track, ids <abbrev>_<label> without a doubled abbrev');

  my $gff = $t->{pfal3D7_UTRs};
  is($gff->{type}, 'FeatureTrack', 'GFF3Tabix: FeatureTrack');
  is_deeply($gff->{adapter},
            {type => 'Gff3TabixAdapter',
             gffGzLocation => {uri => "${S}Pfalciparum3D7/prealigned/gff/utrs.gff.gz", locationType => 'UriLocation'},
             index => {location => {uri => "${S}Pfalciparum3D7/prealigned/gff/utrs.gff.gz.tbi", locationType => 'UriLocation'}}},
            'GFF3Tabix: Gff3TabixAdapter + .tbi, ${nameForFileNames} resolved, store URL kept');
  is($gff->{name}, 'UTRs for P. falciparum 3D7', 'name from key, spaced "key = value", markup stripped');
  is_deeply($gff->{category}, ['Gene Models', 'Transcripts'], 'category then subcategory');
  is_deeply($gff->{assemblyNames}, ['pfal3D7'], 'assemblyNames: the public abbrev');
  is_deeply($gff->{metadata}, {dataset => 'UTRs', trackType => 'Segments'}, 'metadata.* carried, subcategory excluded');
  is_deeply($gff->{displays}, [{type => 'LinearBasicDisplay', displayId => 'pfal3D7_UTRs-LinearBasicDisplay',
                                encoding => {color => {value => 'jexl:veupathProcessedTranscriptColor(feature)'}}}],
            'processedTranscriptColor becomes the VEuPathDBDisplay call');

  my $bed = $t->{pfal3D7_AnidTSS};
  is($bed->{adapter}{type}, 'BedTabixAdapter', 'BEDTabix: BedTabixAdapter');
  is($bed->{adapter}{index}{location}{uri}, "${S}AnidulansFGSCA4/genomeBrowser/bed/sibthorpTSS.bed.gz.tbi", 'BEDTabix: + .tbi');
  ok(!exists $bed->{displays}[0]{encoding}, 'an inline colour function stays stock');

  my $bigbed = $t->{pfal3D7_TSS_curated};
  is_deeply([$bigbed->{type}, $bigbed->{adapter}],
            ['FeatureTrack', {type => 'BigBedAdapter', bigBedLocation => {uri => "${X}ToxoDB/tgonME49/tss.bigBed", locationType => 'UriLocation'}}],
            'BigBed: FeatureTrack + BigBedAdapter');

  my $bw = $t->{pfal3D7_HP1_ring};
  is_deeply([$bw->{type}, $bw->{displays}[0]{type}, $bw->{adapter}{type}],
            ['QuantitativeTrack', 'LinearWiggleDisplay', 'BigWigAdapter'], 'BigWig: QuantitativeTrack');

  my $bam = $t->{pfal3D7_MicroarrayProbes_Affy};
  is_deeply([$bam->{type}, $bam->{displays}[0]{type}, $bam->{adapter}{type}],
            ['AlignmentsTrack', 'LinearAlignmentsDisplay', 'BamAdapter'], 'BAM: AlignmentsTrack');
  is($bam->{adapter}{index}{location}{uri}, "${S}Pfalciparum3D7/microarrayPlatform/bam/Affy/probes.bam.bai",
     'BAM: indexUrlTemplate used for the .bai');

  my $gtf = $t->{'pfal3D7_acasNeff2021-ACANB_genome_annotation'};
  is_deeply($gtf->{adapter}, {type => 'GtfAdapter', gtfLocation => {uri => "${X}AmoebaDB/AcastellaniiNeff2021/ACANB.gtf", locationType => 'UriLocation'}},
            'GTF: GtfAdapter');

  is_deeply($result->{report}{emitted}, {gff3tabix => 1, bedtabix => 1, bigbed => 1, bigwig => 1, multibigwig => 1, bam => 1, gtf => 1},
            'report: emitted by kind');
  is($result->{report}{stanzas}, 8, 'report: stanzas read, REST included');

  my $config = {assemblies => [{name => 'pfal3D7', sequence => {adapter => {type => 'IndexedFastaAdapter',
                  fastaLocation => {uri => "${S}g.fasta", locationType => 'UriLocation'},
                  faiLocation => {uri => "${S}g.fasta.fai", locationType => 'UriLocation'}}}}],
                tracks => $result->{tracks}};
  is_deeply($V->validate($config), [], 'every translated track passes the contract validator');
}

# --- MultiBigWig subtracks ---
{
  my $mbw = byId(translate($ALL))->{pfal3D7_siegelTSS};
  is($mbw->{type}, 'MultiQuantitativeTrack', 'MultiBigWig: MultiQuantitativeTrack');
  is_deeply($mbw->{displays}, [{type => 'LinearWiggleDisplay', displayId => 'pfal3D7_siegelTSS-LinearWiggleDisplay',
                                mark => 'bar', rows => 'source'}], 'MultiBigWig: one wiggle display, a row per source');
  is_deeply($mbw->{adapter},
            {type => 'MultiWiggleAdapter', subadapters => [
              {type => 'BigWigAdapter', name => 'TSS fwd', color => 'blue',
               bigWigLocation => {uri => "${X}TriTrypDB/siegelTSS/fwd.bw", locationType => 'UriLocation'}},
              {type => 'BigWigAdapter', name => 'TSS rev', color => 'red',
               bigWigLocation => {uri => "${X}TriTrypDB/siegelTSS/rev.bw", locationType => 'UriLocation'}}]},
            'MultiBigWig: a named, coloured subadapter per urlTemplates entry, in order');
}

# --- REST ---
{
  my $result = translate($ALL);
  is_deeply($result->{report}{rest}, ['gcContent'], 'REST: not emitted, listed');
  ok(!grep({ $_->{trackId} =~ /gcContent/ } @{$result->{tracks}}), 'REST: no track');
}

# --- unknown class ---
{
  eval { translate("[tracks.odd]\nstoreClass=JBrowse/Store/SeqFeature/VCFTabix\nurlTemplate=${S}a.vcf.gz\n") };
  like($@, qr{^pfal3D7: tracks\.odd: storeClass JBrowse/Store/SeqFeature/VCFTabix has no v5 mapping \(tracks\.conf:1\)},
       'unknown storeClass fails, naming organism, label and class');
  eval { translate("[tracks.none]\nurlTemplate=${S}a.gff.gz\n") };
  like($@, qr{tracks\.conf:1: pfal3D7 \[tracks\.none\]: no storeClass}, 'a stanza without storeClass fails');
}

# --- parse ---
{
  eval { $T->parse("[tracks.a]\nkey=A\n\nstray_dataset_name_RSRC\n\n[tracks.b]\n", 'x/tracks.conf') };
  like($@, qr{^x/tracks\.conf:4: not a section}, 'a stray line fails with file and line');

  eval { $T->parse("[tracks.a]\nmenuTemplate+=json:{\"label\": \n", 'x/tracks.conf') };
  like($@, qr{^x/tracks\.conf:2: menuTemplate: json value does not parse}, 'bad json fails with file and line');

  eval { $T->parse("[general]\ndataRoot=x\n", 'x/tracks.conf') };
  like($@, qr{^x/tracks\.conf:1: section \[general\] is not a \[tracks\.<label>\] stanza}, 'only tracks stanzas');

  eval { $T->parse("key=value\n", 'x/tracks.conf') };
  like($@, qr{^x/tracks\.conf:1: key outside a \[tracks\.<label>\] stanza}, 'a key before any stanza fails');

  my $stanzas = $T->parse(join("\n",
    '# a comment', '[tracks.multi]', 'metadata.description=first line',
    '         second line', '      third line', 'onClick.content=x',
    '# [tracks.commented]', '# storeClass=JBrowse/Store/SeqFeature/REST',
    'urlTemplates+=json:{"url":"u1","name":"n1"}', 'urlTemplates+=json:{"url":"u2","name":"n2"}',
    '[tracks.multi]', 'key=merged', ''), 'x/tracks.conf');
  is(scalar @$stanzas, 1, 'commented-out stanzas are not stanzas; a repeated head merges, as JBrowse 1 does');
  is($stanzas->[0]{values}{'metadata.description'}, 'first line second line third line',
     'indented lines continue the value with one space');
  is_deeply($stanzas->[0]{values}{urlTemplates}, [{url => 'u1', name => 'n1'}, {url => 'u2', name => 'n2'}],
            '+=json: builds an array of decoded values');
  is($stanzas->[0]{values}{key}, 'merged', 'the repeated head adds its keys');
  is($stanzas->[0]{line}, 2, 'a stanza remembers its first line');

  eval { translate("[tracks.v]\nstoreClass=JBrowse/Store/SeqFeature/BigWig\nurlTemplate=${S}\${dataRoot}/a.bw\n") };
  like($@, qr{unresolved template variable}, 'a template variable other than nameForFileNames fails');
}

# --- styling ---
{
  my $result = translate($ALL);
  my @unmapped = map { "$_->{label} $_->{key}" } @{$result->{report}{unmapped}};
  is_deeply(\@unmapped,
            ['AnidTSS style.color', 'MicroarrayProbes_Affy menuTemplate', 'MicroarrayProbes_Affy onClick.content',
             'acasNeff2021-ACANB_genome_annotation style.borderColor', 'acasNeff2021-ACANB_genome_annotation style.color'],
            'unmapped: every styling or details callback without a VEuPathDBDisplay port, never fmtMetaValue_*');
  my ($alt) = grep { $_->{key} eq 'style.color' && $_->{label} =~ /acas/ } @{$result->{report}{unmapped}};
  is_deeply($alt, {organism => 'pfal3D7', label => 'acasNeff2021-ACANB_genome_annotation', key => 'style.color',
                   callback => '{alternateTranscriptColor}'}, 'an unmapped entry names organism, label and callback text');

  my $piggy = byId(translate("[tracks.AdamsPiggyBac]\nstoreClass=JBrowse/Store/SeqFeature/GFF3Tabix\n"
                           . "urlTemplate=${S}p.gff.gz\nstyle.color={piggyBacColor}\n"))->{pfal3D7_AdamsPiggyBac};
  is($piggy->{displays}[0]{encoding}{color}{value}, "jexl:veupathStrandColor(feature, 'dodgerblue', 'mediumvioletred')",
     'piggyBacColor becomes veupathStrandColor with its JBrowse 1 colours');

  my $covered = translate("[tracks.t]\nstoreClass=JBrowse/Store/SeqFeature/GFF3Tabix\nurlTemplate=${S}t.gff.gz\n"
                        . "style.color={processedTranscriptColor}\ntranscriptType={geneTranscriptType}\n");
  is_deeply($covered->{report}{unmapped}, [], 'geneTranscriptType is covered by veupathProcessedTranscriptColor');
  my $notCovered = translate("[tracks.t]\nstoreClass=JBrowse/Store/SeqFeature/GFF3Tabix\nurlTemplate=${S}t.gff.gz\n"
                           . "style.color={alternateTranscriptColor}\ntranscriptType={geneTranscriptType}\n");
  is(scalar @{$notCovered->{report}{unmapped}}, 2, '... but not beside an unmapped fill');

  my $bw = translate("[tracks.w]\nstoreClass=JBrowse/Store/SeqFeature/BigWig\nurlTemplate=${S}w.bw\nstyle.color={processedTranscriptColor}\n");
  ok(!exists $bw->{tracks}[0]{displays}[0]{encoding}, 'a fill is only set on LinearBasicDisplay');
}

# --- trackId determinism ---
{
  my $conf = "[tracks.Odd label (v2) - final]\nstoreClass=JBrowse/Store/SeqFeature/BigWig\nurlTemplate=${S}w.bw\n";
  my $first = translate($conf)->{tracks}[0]{trackId};
  is($first, 'pfal3D7_Odd_label_v2_final', 'trackId sanitized to the contract pattern');
  is(translate($conf)->{tracks}[0]{trackId}, $first, 'and the same on every run');
  is($T->trackIdFor($ORG, 'pfal3D7_x'), 'pfal3D7_x', 'a label already carrying the abbrev is not prefixed twice');
  is($T->trackIdFor({abbrev => 'cneoJEC21', internal_abbrev => 'cdenJEC21'}, 'cdenJEC21_x'), 'cneoJEC21_x',
     'an internal-abbrev prefix becomes the public one');
  is_deeply([map { $_->{trackId} } @{translate($ALL)->{tracks}}],
            [map { $_->{trackId} } @{translate($ALL)->{tracks}}], 'track order is file order, every run');
}

# --- locations for the mirror check ---
{
  my $uris = translate($ALL)->{uris};
  my ($bam) = grep { $_->{trackId} eq 'pfal3D7_MicroarrayProbes_Affy' } @$uris;
  ok($bam, 'every emitted track lists the locations it reads');
  is(scalar(grep { $_->{trackId} eq 'pfal3D7_siegelTSS' } @$uris), 2, 'MultiBigWig: one location per subadapter');
}

done_testing();
