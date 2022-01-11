#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl"; 
use Data::Dumper;
use Text::CSV;
use Encode qw( decode_utf8 );

&usage() unless scalar(@ARGV) == 3;

my $inputDir = $ARGV[0];
my $outputDir = $ARGV[1];
my $releaseNum = $ARGV[2];

my $outputDatasetFile = $outputDir."/new_mapveu_datasets.xml";
my $outputPresenterFile = $outputDir."/new_mapveu_presenters.xml";
my $outputContactsFile = $outputDir."/new_mapveu_contacts.xml";

my $datasetFolders = &getFolders($inputDir,$releaseNum);
&makeDatasets($datasetFolders,$outputDatasetFile,$outputPresenterFile,$outputContactsFile,$releaseNum);

exit;



sub getFolders {
    my ($inputDir,$releaseNum) = @_;
    $inputDir .= "/rel-$releaseNum/loaded";
    my @datasetFolders;
    print "Getting folders for each study/dataset:\n";
    opendir my $dir, $inputDir or die "Cannot open directory: $!";
    my @files = readdir $dir;
    closedir $dir;
    foreach my $file (@files) {
	if (-e "${inputDir}/${file}/i_investigation.txt") {
	    print "    ${inputDir}/${file}\n";
	    push @datasetFolders, "${inputDir}/${file}";
	} elsif (-e "${inputDir}/${file}/isa-tab/i_investigation.txt") {
	    print "    ${inputDir}/${file}/isa-tab\n";
	    push @datasetFolders, "${inputDir}/${file}/isa-tab";
	} elsif ($file eq "." || $file eq "..") {
	    print "    Skipping $file\n";
	} else {
	    die "Could not find i_investigation.txt file within $file";
	}
    }
    return \@datasetFolders;
}

sub makeDatasets {
    my ($datasetFolders,$outputDatasetFile,$outputPresenterFile,$outputContactsFile,$releaseNum) = @_;
    print "\nWriting these files:\n";
    print "    ".join("\n    ",($outputDatasetFile,$outputPresenterFile,$outputContactsFile))."\n";
    open(my $datasetFh,'>', $outputDatasetFile) or die "Unable to read file $outputDatasetFile.\n";
    open(my $presenterFh,'>', $outputPresenterFile) or die "Unable to read file $outputPresenterFile.\n";
    open(my $contactsFh,'>', $outputContactsFile) or die "Unable to read file $outputContactsFile.\n";
    foreach my $folder (@{$datasetFolders}) {
	my %datasetInfo;
	$datasetInfo{Release} = $releaseNum;
	&processInvestigationFile($folder."/i_investigation.txt",\%datasetInfo);
	&processSampleFile($folder."/sample-info.txt",\%datasetInfo);
	&translateToHtml(\%datasetInfo);
	&printToDatasetFile($datasetFh,\%datasetInfo);
	&printToPresenterFile($presenterFh,\%datasetInfo);
	&printToContactsFile($contactsFh,\%datasetInfo);
    }
    close $datasetFh; close $presenterFh; close $contactsFh;
}

sub processSampleFile {
    my ($file,$datasetInfo) = @_;
    my $vbId = "";
    open(my $fh, $file) or die "Unable to read file $file.\n";
    while (my $line = <$fh>) {
	if ($line =~ /(VBP\d+)[^\d]/) {
	    my $id = $1;
	    die "There are >1 VBP Ids in this file: $file" if ($vbId ne "");
	    $vbId = $id;
	}
    }
    die "There is no VBP Id in this file: $file" if ($vbId eq "");
    $datasetInfo->{VBP_ID} = $vbId;
}

sub processInvestigationFile {
    my ($file,$datasetInfo) = @_;
    open(my $fh, $file) or die "Unable to read file $file.\n";
    while (my $line = <$fh>) {
	chomp $line;
        my @array = split(/\t/,$line);
	next if (scalar @array < 2);
	if ($array[0] =~ /"Study Title"/) {
	    $datasetInfo->{Title} = $array[1];
	} elsif ($array[0] =~ /"Study Submission Date"/) {
	    $datasetInfo->{Date} = $array[1];
	} elsif ($array[0] =~ /"Study Description"/) {
	    $datasetInfo->{Description} = $array[1];
	} elsif ($array[0] =~ /"Study PubMed ID"/) {
	    $datasetInfo->{Pubmed} = &addToArray($datasetInfo->{Pubmed},$array[1]);
	} elsif ($array[0] =~ /"Study Person Last Name"/) {
	    $datasetInfo->{Last_Name} = $array[1];
	} elsif ($array[0] =~ /"Study Person First Name"/) {
	    $datasetInfo->{First_Name} = $array[1];
	} elsif ($array[0] =~ /"Study Person Mid Initials"/) {
	    $datasetInfo->{Middle_Initials} = $array[1];
	} elsif ($array[0] =~ /"Study Person Email"/) {
	    $datasetInfo->{Email} = $array[1];
	} elsif ($array[0] =~ /"Study Person Affiliation"/) {
	    $datasetInfo->{Affiliation} = $array[1];
	}
    }
    $datasetInfo->{Full_Name} = $datasetInfo->{First_Name} if (exists $datasetInfo->{First_Name});
    $datasetInfo->{Full_Name} .= " ".$datasetInfo->{Middle_Initials} if (exists $datasetInfo->{Middle_Initials} && $datasetInfo->{Middle_Initials} ne "");
    $datasetInfo->{Full_Name} .= " ".$datasetInfo->{Last_Name} if (exists $datasetInfo->{Last_Name});
    s/^\s+|\s+$//g foreach (@{$datasetInfo->{Pubmed}});
    close $fh;
}

sub printToDatasetFile {
    my ($fh,$row) = @_;
    my $version = $row->{Date};
    my $vbId = $row->{VBP_ID};
    print $fh "  <dataset class=\"PopBio_temp\">\n";
    print $fh "    <prop name=\"version\">${version}</prop>\n";
    print $fh "    <prop name=\"vbId\">${vbId}</prop>\n";
    print $fh "    <prop name=\"projectName\">\$\$projectName\$\$</prop>\n";
    print $fh "  </dataset>\n\n";
}

sub printToPresenterFile {
    my ($fh,$row) = @_;
    my $title = $row->{Title};
    my $description = $row->{Description};
    my $vbId = $row->{VBP_ID};
    my $build = $row->{Release};
    my $name = $row->{Full_Name};
    my $contact = $name eq "" ? "unidentified" : "popbio_temp_".$row->{VBP_ID};
    my $pubmedIds = $row->{Pubmed};
    print "\nProcessing title '$title'\n";
    my $length = length($title);
    print "    Length of title without the <![CDATA[]]>: $length\n";
    &checkPubMedIds($pubmedIds);
    push @{$pubmedIds}, "" if (scalar @{$pubmedIds} == 0);

    print $fh "  <datasetPresenter name=\"PopBio_temp_${vbId}_RSRC\"\n";
    print $fh "                    projectName=\"VectorBase\">\n";
    print $fh "    <displayName><![CDATA[${title}]]></displayName>\n";
    print $fh "    <shortDisplayName><![CDATA[${title}]]></shortDisplayName>\n";
    print $fh "    <shortAttribution></shortAttribution>\n";
    print $fh "    <summary><![CDATA[${description}]]></summary>\n";
    print $fh "    <description><![CDATA[${description}]]></description>\n";
    print $fh "    <caveat></caveat>\n";
    print $fh "    <acknowledgement></acknowledgement>\n";
    print $fh "    <releasePolicy></releasePolicy>\n";
    print $fh "    <history build=\"${build}\"></history>\n";
    print $fh "    <primaryContactId>${contact}</primaryContactId>\n";
    print $fh "    <link>\n";
    print $fh "      <text>View Data in MapVEu</text>\n";
    print $fh "      <url>https://vectorbase.org/popbio-map/web/?projectID=${vbId}</url>\n";
    print $fh "    </link>\n";
    print $fh "    <pubmedId>$_</pubmedId>\n" foreach @{$pubmedIds};
    print $fh "    <templateInjector className=\"org.apidb.apicommon.model.datasetInjector.PopBio\"/>\n";
    print $fh "  </datasetPresenter>\n\n";
}

sub checkPubMedIds {
    my ($pubmedIds) = @_;
    foreach my $id (@{$pubmedIds}) {
	my $url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?api_key=f2006d7a9fa4e92b2931d964bb75ada85a08&db=pubmed&retmode=xml&rettype=abstract&id=$id";
	print "    Getting PubMed ID '$id'";
	my $cmd = "curl --max-time 600 --silent --show-error -g '$url'";
	my $xml = `$cmd`;
	if ($xml && ($xml =~ /(aedes|anopheles|insect|mosquito|plasmodium|ixodes|parasite|vector)/i)) {
	    print "        ID is likely correct. Found this text: $1\n";
	} else {
	    print "        Check whether this ID is correct\n";
	    print Dumper $xml;
	}
    }
}

sub printToContactsFile {
    my ($fh,$row) = @_;
    return if ($row->{Full_Name} eq "");
    my $contactId = "popbio_temp_".$row->{VBP_ID};
    my $name = $row->{Full_Name};
    my $institution = exists $row->{Affiliation} ? $row->{Affiliation} : "";
    my $email = exists $row->{Email} ? $row->{Email} : "";
    print $fh "  <contact>\n";
    print $fh "    <contactId>${contactId}</contactId>\n";
    print $fh "    <name>${name}</name>\n";
    print $fh "    <institution>${institution}</institution>\n";
    print $fh "    <email>${email}</email>\n";
    print $fh "    <address/>\n";
    print $fh "    <city/>\n";
    print $fh "    <state/>\n";
    print $fh "    <zip/>\n";
    print $fh "    <country/>\n";
    print $fh "  </contact>\n\n";
}

sub translateToHtml {
    my ($row) = @_;
    foreach my $key (keys %{$row}) {
	next if ($key eq "Pubmed");
	my $unicode_string = decode_utf8($row->{$key});
	$unicode_string =~ s/^\s+|\s+$//g;
	$unicode_string =~ s/^"|"$//g;
	$unicode_string =~ s/^\s+|\s+$//g;
	$unicode_string =~ s/&/&amp;/g;
	$row->{$key} = join q(), map { ord > 127 ? "&#" . ord . ";" : $_ } split //, $unicode_string;
    }
}

sub splitAndClean {
    my ($string,$delimiter) = @_;
    my @array = split("$delimiter",$string);
    s/^\s+|\s+$//g foreach @array;
    return \@array;
}

sub readDelimitedFile {
    my ($file,$delimiter) = @_;
    print "Reading delimited file:  '$file'\nDelimiter: '$delimiter'\n";
    open(my $fh, $file) or die "Unable to read file $file.\n";
    my $header = &readHeaderLine($fh,$delimiter);
    my @data;
    while (my $line = <$fh>) {
	my $rowArray = &readDelimitedLine($line,$delimiter);
	push @data, &addHeadersToRow($header,$rowArray);
    }
    close $fh;
    return \@data;
}

sub addHeadersToRow {
    my ($header,$rowArray) = @_;
    my $numColsHeader = scalar @{$header};
    my $numColsRow = scalar @{$rowArray};
    if ($numColsHeader != $numColsRow) {
	print "This row has $numColsRow columns but the header has $numColsHeader columns:\n";
	for (my $i=0; $i<$numColsRow; $i++) {
	    print "column $i: .$rowArray->[$i]\n";
	}
	die;
    }
    my %hash;
    for (my $i=0; $i<$numColsHeader; $i++) {
	$hash{$header->[$i]} = $rowArray->[$i];
#	print "$header->[$i]: $rowArray->[$i]\n";
    }
    return \%hash;
}

sub readHeaderLine {
    my ($fh,$delimiter) = @_;
    my $line = <$fh>;
    my $header = &readDelimitedLine($line,$delimiter);
    print "Headers:";
    s/ /_/g foreach @{$header};
    print " '".$_."'" foreach @{$header};
    print "\n";
    return $header;
}

sub readDelimitedLine {
    my ($line,$delimiter) = @_;
    $line =~ s/[\n\r]//g;
    $line =~ s/^\s+|\s+$//g;
    my @array = split("$delimiter",$line);
    return &cleanArray(\@array);
}

sub cleanArray {
    my ($rowArray) = @_;
    my @rowArrayClean;
    my $inQuote = "";
    foreach my $value (@{$rowArray}) {
	$value =~ s/^\s+|\s+$//g;
	$value =~ s/^\.//;
	if ($value =~ /^"/) {
	    $value =~ s/^"//;
	    if ($value =~ /"$/) {
		$value =~ s/"$//;
		push @rowArrayClean, $value;
	    } else {
		$inQuote = $value;
	    }
	} else {
	    if ($value =~ /"$/) {
		$value =~ s/"$//;
		push @rowArrayClean, $inQuote.$value;
		$inQuote = "";
	    } else {
		if ($inQuote ne "") {
		    $inQuote .= $value;
		} else {
		    push @rowArrayClean, $value;
		}
	    }
	}
    }
    return \@rowArrayClean;
}


sub addToArray {
    my ($arrayRef,$element) = @_;
    if (defined $arrayRef) {
        push @{$arrayRef}, $element;
    } else {
        $arrayRef = [$element];
    }
    return $arrayRef;
} 

sub uniprotRefDataset {
    my ($proteomeRef) = @_;
    my @need = ("core_peripheral","Uniprot_num","species","ncbi_taxon","abbrev","orthomclClade","kingdom");
    testFields($proteomeRef,\@need);
    my @text;
    push @text, "\t<dataset class=\"orthomclUniprotReferenceProteomeFor${$proteomeRef}{core_peripheral}\">";
    push @text, "\t\t<prop name=\"proteomeId\">${$proteomeRef}{Uniprot_num}</prop>";
    push @text, "\t\t<prop name=\"organismName\">${$proteomeRef}{species}</prop>";
    push @text, "\t\t<prop name=\"ncbiTaxonId\">${$proteomeRef}{ncbi_taxon}</prop>";
    push @text, "\t\t<prop name=\"abbrev\">${$proteomeRef}{abbrev}</prop>";
    if (${$proteomeRef}{core_peripheral} eq "Peripheral") {
	push @text, "\t\t<prop name=\"orthomclClade\">${$proteomeRef}{orthomclClade}</prop>";
    }
    push @text, "\t\t<prop name=\"oldAbbrevsList\">${$proteomeRef}{oldAbbrevsList}</prop>";
    push @text, "\t\t<prop name=\"kingdom\">${$proteomeRef}{kingdom}</prop>";
    push @text, "\t</dataset>\n";
    if ( ${$proteomeRef}{makeEcDatasets} =~ /^[Yy]/ ) {
	push @text, "\t<dataset class=\"orthomclUniprotEcFor${$proteomeRef}{core_peripheral}\">";
	push @text, "\t\t<prop name=\"ncbiTaxonId\">${$proteomeRef}{ncbi_taxon}</prop>";
	push @text, "\t\t<prop name=\"abbrev\">${$proteomeRef}{abbrev}</prop>";
	push @text, "\t</dataset>\n";
    }
    return \@text;
}

sub vectorbaseDataset {
    my ($proteomeRef) = @_;
    my @need = ("core_peripheral","vectorBaseLongName","ncbi_taxon","abbrev","vectorBaseShortName","species","orthomclClade","biomartDataset");
    testFields($proteomeRef,\@need);
    my @text;
    push @text, "\t<dataset class=\"orthomclVectorbaseProteomeFor${$proteomeRef}{core_peripheral}\">";
    push @text, "\t\t<prop name=\"vectorBaseLongName\">${$proteomeRef}{vectorBaseLongName}</prop>";
    push @text, "\t\t<prop name=\"vectorBaseShortName\">${$proteomeRef}{vectorBaseShortName}</prop>";
    push @text, "\t\t<prop name=\"organismName\">${$proteomeRef}{species}</prop>";
    push @text, "\t\t<prop name=\"ncbiTaxonId\">${$proteomeRef}{ncbi_taxon}</prop>";
    push @text, "\t\t<prop name=\"abbrev\">${$proteomeRef}{abbrev}</prop>";
    if (${$proteomeRef}{core_peripheral} eq "Peripheral") {
	push @text, "\t\t<prop name=\"orthomclClade\">${$proteomeRef}{orthomclClade}</prop>";
    }
    push @text, "\t\t<prop name=\"oldAbbrevsList\">${$proteomeRef}{oldAbbrevsList}</prop>";
    push @text, "\t</dataset>\n";
    if ( ${$proteomeRef}{makeEcDatasets} =~ /^[Yy]/ ) {
	push @text, "\t<dataset class=\"orthomclVectorbaseEcFor${$proteomeRef}{core_peripheral}\">";
	push @text, "\t\t<prop name=\"ncbiTaxonId\">${$proteomeRef}{ncbi_taxon}</prop>";
	push @text, "\t\t<prop name=\"abbrev\">${$proteomeRef}{abbrev}</prop>";
	push @text, "\t\t<prop name=\"biomartDataset\">${$proteomeRef}{biomartDataset}</prop>";
	push @text, "\t</dataset>\n";
    }
    return \@text;
}


sub eupathDataset {
    my ($proteomeRef) = @_;
    my @need = ("core_peripheral","ncbi_taxon","abbrev","species","orthomclClade","eupath_project","eupath_project","webSubDir","ncbiTaxonIdIsAtSpeciesLevel");
    testFields($proteomeRef,\@need);
    my @text;
    push @text, "\t<dataset class=\"orthomclEuPathProteomeFor${$proteomeRef}{core_peripheral}\">";
    push @text, "\t\t<prop name=\"ncbiTaxonIdIsAtSpeciesLevel\">${$proteomeRef}{ncbiTaxonIdIsAtSpeciesLevel}</prop>";
    push @text, "\t\t<prop name=\"organismName\">${$proteomeRef}{species}</prop>";
    push @text, "\t\t<prop name=\"ncbiTaxonId\">${$proteomeRef}{ncbi_taxon}</prop>";
    push @text, "\t\t<prop name=\"abbrev\">${$proteomeRef}{abbrev}</prop>";
    if (${$proteomeRef}{core_peripheral} eq "Peripheral") {
	push @text, "\t\t<prop name=\"orthomclClade\">${$proteomeRef}{orthomclClade}</prop>";
    }
    push @text, "\t\t<prop name=\"oldAbbrevsList\">${$proteomeRef}{oldAbbrevsList}</prop>";
    push @text, "\t\t<prop name=\"project\">${$proteomeRef}{eupath_project}</prop>";
    push @text, "\t\t<prop name=\"webSubDir\">${$proteomeRef}{webSubDir}</prop>";   
    push @text, "\t\t<prop name=\"version\">${$proteomeRef}{eupath_version}</prop>";
    push @text, "\t</dataset>\n";
    if ( ${$proteomeRef}{makeEcDatasets} =~ /^[Yy]/ ) {
	${$proteomeRef}{species} =~ s/ /%20/g;
	${$proteomeRef}{species} =~ s/#/%23/g;
	push @text, "\t<dataset class=\"orthomclEuPathEcFor${$proteomeRef}{core_peripheral}\">";
	push @text, "\t\t<prop name=\"version\">${$proteomeRef}{eupath_version}</prop>";
	push @text, "\t\t<prop name=\"abbrev\">${$proteomeRef}{abbrev}</prop>";
	push @text, "\t\t<prop name=\"project\">${$proteomeRef}{eupath_project}</prop>";
	push @text, "\t\t<prop name=\"webSubDir\">${$proteomeRef}{webSubDir}</prop>";   
	push @text, "\t\t<prop name=\"organismName\">${$proteomeRef}{species}</prop>";
	push @text, "\t</dataset>\n";
    }
    return \@text;
}

sub manualDeliveryDataset {
    my ($proteomeRef) = @_;
    my @text;
    push @text, "\t<dataset class=\"orthomclManualDeliveryProteomeFor${$proteomeRef}{core_peripheral}\">";
    push @text, "\t\t<prop name=\"species\">${$proteomeRef}{manualDeliveryName}</prop>";
    push @text, "\t\t<prop name=\"ncbiTaxonId\">${$proteomeRef}{ncbi_taxon}</prop>";
    push @text, "\t\t<prop name=\"abbrev\">${$proteomeRef}{abbrev}</prop>";
    if (${$proteomeRef}{core_peripheral} eq "Peripheral") {
	push @text, "\t\t<prop name=\"orthomclClade\">${$proteomeRef}{orthomclClade}</prop>";
    }
    push @text, "\t\t<prop name=\"oldAbbrevsList\">${$proteomeRef}{oldAbbrevsList}</prop>";
    push @text, "\t\t<prop name=\"project\">${$proteomeRef}{eupath_project}</prop>";
    push @text, "\t\t<prop name=\"version\">${$proteomeRef}{manualDeliveryVersion}</prop>";
    push @text, "\t</dataset>\n";
    return \@text;
}

sub formatOldAbbrevsList {
    my ($abbrev,$list) = @_;
    my @elements = split(",",$list);
    my @newElements;
    foreach my $element (@elements) {
	$element =~ s/ //g;
	if ($element =~ /^(\S+):(\S+)$/ ) {
	    my ($version, $organism) = ($1,$2);
	    next if $version eq '2.2';
	    next if $organism eq $abbrev;
	    push @newElements, $element;
	}
    }
    return join(", ",@newElements);
}

sub getWebSubDirFromProject {
    my %projectToDir = (
	MicrosporidiaDB => "micro",
	ToxoDB => "toxo",
	AmoebaDB => "amoeba",
	CryptoDB => "cryptodb",
	FungiDB => "fungidb",
	GiardiaDB => "giardiadb",
	PiroplasmaDB => "piro",
	PlasmoDB => "plasmo",
	TrichDB => "trichdb",
	TriTrypDB => "tritrypdb",
	HostDB => "hostdb",
	);
    return \%projectToDir;
}

sub getKingdomFromOneLetter {
    my %oneLetterToKingdom = (
	A => 'Archaea',
        B => 'Bacteria',
        E => 'Eukaryota',
        V => 'Viruses',
        O => 'Others');
    return \%oneLetterToKingdom;
}

sub getKingdomFromClade {
    my %cladeToKingdom = (
        BACT => "Bacteria",
        FIRM => "Bacteria",
        PROT => "Bacteria",
        PROA => "Bacteria",
        PROB => "Bacteria",
        PROD => "Bacteria",
        PROG => "Bacteria",
        PROE => "Bacteria",
        OBAC => "Bacteria",
        ARCH => "Archaea",
        EURY => "Archaea",
        CREN => "Archaea",
        NANO => "Archaea",
        KORA => "Archaea",
        EUKA => "Eukaryota",
        CILI => "Eukaryota",
        ALVE => "Eukaryota",
        APIC => "Eukaryota",
        COCC => "Eukaryota",
        ACON => "Eukaryota",
        HAEM => "Eukaryota",
        PIRO => "Eukaryota",
        AMOE => "Eukaryota",
        EUGL => "Eukaryota",
        VIRI => "Eukaryota",
        STRE => "Eukaryota",
        CHLO => "Eukaryota",
        RHOD => "Eukaryota",
        CRYP => "Eukaryota",
        BACI => "Eukaryota",
        FUNG => "Eukaryota",
        MICR => "Eukaryota",
        BASI => "Eukaryota",
        ASCO => "Eukaryota",
        MUCO => "Eukaryota",
        CHYT => "Eukaryota",
        META => "Eukaryota",
        PLAT => "Eukaryota",
        NEMA => "Eukaryota",
	ARTH => "Eukaryota",
	CHOR => "Eukaryota",
	ACTI => "Eukaryota",
	AVES => "Eukaryota",
	MAMM => "Eukaryota",
	TUNI => "Eukaryota",
	OMET => "Eukaryota",
	OEUK => "Eukaryota",
        OOMY => "Eukaryota",
        );
    return \%cladeToKingdom;
}

sub getTaxonToKingdom {
    my ($downloadUniprotTaxonFile,$oneLetterToKingdom) = @_;
    if ($downloadUniprotTaxonFile =~ /^[Yy]/) {
	my $cmd = "wget https://www.uniprot.org/docs/speclist.txt";
	system($cmd);
    }
    my %taxonToKingdom;
    open(specFH, "speclist.txt") or die "Unable to read file speclist.txt\n";
    while (<specFH>) {
	if (/^\w+\s+([ABEVO])\s+(\d+):\s/) {
	    my ($kingdom, $taxonId) = ($1,$2);
	    $kingdom = $oneLetterToKingdom->{$kingdom};
	    $taxonToKingdom{$taxonId} = $kingdom;
	} 
    }
    close specFH;
    return \%taxonToKingdom;
}

sub testFields {
    my ($proteomeRef,$arrayRef) = @_;
    foreach my $field (@$arrayRef) {
	if (!exists $proteomeRef->{$field} || $proteomeRef->{$field} eq "") {
	    die "The expected field '$field' does not exist for abbrev '$proteomeRef->{abbrev}'\n";
	}
    }
}


sub usage {
    print "\nmapveuMakeDatasets <input-dir> <output-dir> <release-number>\n\n";
    print "For example:  mapveuMakeDatasets /home/skelly/vectorbase/popbio/data/isa-tab . 55\n";
    print "This command will use i_investigation.txt and sample-info.txt files from\n";
    print "the directory /home/skelly/vectorbase/popbio/data/isa-tab/rel-55/loaded/*/\n";
    print " and /home/skelly/vectorbase/popbio/data/isa-tab/rel-55/loaded/*/isa-tab/\n";
    print "and place three output files into the current directory. The three files will\n";
    print "be datasets.xml, presenters.xml, and contacts.xml.\n";
    exit;
}
