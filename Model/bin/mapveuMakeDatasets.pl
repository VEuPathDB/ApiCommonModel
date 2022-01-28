#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl"; 
use Data::Dumper;
use Text::CSV;
use Encode qw( decode_utf8 );

&usage() unless scalar(@ARGV) == 4;

my $inputDir = $ARGV[0];
my $presenterFile = $ARGV[1];
my $outputDir = $ARGV[2];
my $releaseNum = $ARGV[3];

my $existingDatasets = &getExistingDatasets($presenterFile);

my $outputDatasetFile = $outputDir."/new_mapveu_datasets.xml";
my $outputPresenterFile = $outputDir."/new_mapveu_presenters.xml";
my $outputContactsFile = $outputDir."/new_mapveu_contacts.xml";

my $datasetFolders = &getFolders($inputDir,$releaseNum);
&makeDatasets($datasetFolders,$outputDatasetFile,$outputPresenterFile,$outputContactsFile,$releaseNum,$existingDatasets);

exit;


sub getExistingDatasets {
    my ($presenterFile) = @_;
    my %datasets;

    open(my $inFh,'<', $presenterFile) or die "Unable to read file $presenterFile.\n";
    while (my $line = <$inFh>) {
	if ($line =~ /<datasetPresenter name="PopBio_Study_(VBP\d+)_RSRC"/) {
	    $datasets{$1} = 1;
	}
    }
    close $inFh;
    return \%datasets;
}

sub getFolders {
    my ($inputDir,$releaseNum) = @_;
    $inputDir .= "/rel-$releaseNum/loaded";
    my @datasetFolders;
    print "\nGetting folders for each study/dataset:\n";
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
	} elsif ($file eq "remediations") {
	    print "    Skipping ${inputDir}/${file}\n";
	} elsif ($file eq "." || $file eq "..") {
	    print "    Skipping ${inputDir}/${file}\n";
	} else {
	    print "    ERROR: Could not find i_investigation.txt file within ${inputDir}/${file}\n";
	}
    }
    return \@datasetFolders;
}

sub makeDatasets {
    my ($datasetFolders,$outputDatasetFile,$outputPresenterFile,$outputContactsFile,$releaseNum,$existingDatasets) = @_;
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
	&printToPresenterFile($presenterFh,\%datasetInfo,$existingDatasets);
	&printToContactsFile($contactsFh,\%datasetInfo);
    }
    close $datasetFh; close $presenterFh; close $contactsFh;
    print "\n";
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
    $datasetInfo->{Sample_file} = $file;
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
	} elsif ($array[0] =~ /"Study Publication DOI"/) {
	    $datasetInfo->{Doi} = &addToArray($datasetInfo->{Doi},$array[1]);
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
    s/^\s+|\s+$//g foreach (@{$datasetInfo->{Doi}});
    close $fh;
    $datasetInfo->{Investigation_file} = $file;
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
    my ($fh,$row,$existingDatasets) = @_;
    my $title = $row->{Title};
    my $description = $row->{Description};
    my $vbId = $row->{VBP_ID};
    my $build = $row->{Release};
    my $name = $row->{Full_Name};
    my $contact = $name eq "" ? "unidentified" : "popbio_temp_".$row->{VBP_ID};
    my $pubmedIds = $row->{Pubmed};
    my $DOIs = $row->{Doi};
    my $sampleFile = $row->{Sample_file};
    my $investFile = $row->{Investigation_file};

    print "\nProcessing $vbId\n";
    print "    ALERT: This dataset is already in the presenter-file. You may need to replace or update the previous entry.\n" if (exists $existingDatasets->{$vbId});
    print "    Sample file: $sampleFile\n";
    print "    Investigation file: $investFile\n";
    print "    Title: '$title'\n";

    my $length = length($title);
    print "          Length of title without the <![CDATA[]]>: $length\n";
    my $numPubmed = scalar @{$pubmedIds};
    my $numDOI = scalar @{$DOIs};
    print "    Num Pubmed Ids: $numPubmed    Num DOIs: $numDOI\n";
    &checkPubMedIds($pubmedIds);
    push @{$pubmedIds}, "" if ($numPubmed == 0);

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

    if ($numDOI > $numPubmed) {
	&checkDOIs($DOIs);
	foreach my $id (@{$DOIs}) {
	    my $url = "https://www.doi.org/" . $id;
	    print $fh "    <link isPublication=\"yes\">\n";
	    print $fh "      <text>Publication DOI</text>\n";
	    print $fh "      <url>$url</url>\n";
	    print $fh "    </link>\n";
	}
    }
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
	    print "    ID is likely correct. Found this text: $1\n";
	} else {
	    print "\n        ALERT: Did not find a keyword. Check whether this ID is correct.\n";
	}
    }
}

sub checkDOIs {
    my ($DOIs) = @_;
    foreach my $id (@{$DOIs}) {
	my $url = "https://www.doi.org/" . $id;
	print "    Getting DOI at '$url'";
	my $cmd = "curl --max-time 600 --silent --show-error -g -L '$url'";
	my $text = `$cmd`;
	if ($text && ($text =~ /(aedes|anopheles|insect|mosquito|plasmodium|ixodes|parasite|vector)/i)) {
	    print "    ID is likely correct. Found this text: $1\n";
	} else {
	    print "\n        ALERT: Did not find a keyword. Check whether this ID is correct.\n";
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
	next if ($key eq "Pubmed" || $key eq "Doi");
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

sub usage {
    print "\nmapveuMakeDatasets <input-dir> <presenter-file> <output-dir> <release-number>\n\n";
    print "For example:  mapveuMakeDatasets /home/skelly/vectorbase/popbio/data/isa-tab\n";
    print "      /home/skelly/project_home/ApiCommonPresenters/Model/lib/xml/datasetPresenters/VectorBase.xml\n";
    print "      . 55\n";
    print "This command will use i_investigation.txt and sample-info.txt files from\n";
    print "the directories /home/skelly/vectorbase/popbio/data/isa-tab/rel-55/loaded/*/\n";
    print " and /home/skelly/vectorbase/popbio/data/isa-tab/rel-55/loaded/*/isa-tab/\n";
    print "and place three output files into the current directory (indicated by the period).\n";
    print "The three files will be new_mapveu_datasets.xml, new_mapveu_presenters.xml, and\n";
    print "new_mapveu_contacts.xml.\n";
    print "If a study has already been loaded into the presenter-file, the script will still write out the study\n";
    print "to the new files but will notify you.\n";
    print "Note that the 'remediations' folder will be skipped.\n";
    exit;
}
