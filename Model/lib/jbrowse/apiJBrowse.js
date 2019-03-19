/* global Balloon, jQuery, Wdk, apidb */

/****** Table-building utilities ******/

function table(rows) {
  return '<table border="0">' + rows.join('') + '</table>';
}

function twoColRow(left, right) {
  return '<tr><td>' + left + '</td><td>' + right + '</td></tr>';
}

function fiveColRow(one, two, three, four, five) {
  return '<tr><td>' + one + '</td><td>' + two + '</td><td>' + three + '</td><td>' + four + '</td><td>' + five + '</td></tr>';
}

/******  utilities ******/

positionString = function(refseq, start, end, strand)  {
    var strandString = strand == 1 ? "(+ strand)" : "(- strand)";
    return refseq + ":" + start + ".." + end + " " + strandString;
}

function round(value, decimals) {
  return Number(Math.round(value+'e'+decimals)+'e-'+decimals);
}


function titleCase(str) {
   var splitStr = str.toLowerCase().split(' ');
   for (var i = 0; i < splitStr.length; i++) {
       splitStr[i] = splitStr[i].charAt(0).toUpperCase() + splitStr[i].substring(1);     
   }
   return splitStr.join(' '); 
}

/****** Pop-up functions for various record types ******/

// Gene title
function gene_title (tip, projectId, sourceId, chr, loc, soTerm, product, taxon, utr, position, orthomcl, geneId, dataRoot, baseUrl, baseRecordUrl, aaseqid ) {

  // In ToxoDB, sequences of alternative gene models have to be returned
  var ignore_gene_alias = 0;
  if (projectId == 'ToxoDB') {
    ignore_gene_alias = 1;
  }

  // expand minimalist input data
  var cdsLink = "<a href='/cgi-bin/geneSrt?project_id=" + projectId
    + "&ids=" + sourceId
    + "&ignore_gene_alias=" + ignore_gene_alias
    + "&type=CDS&upstreamAnchor=Start&upstreamOffset=0&downstreamAnchor=End&downstreamOffset=0&go=Get+Sequences' target='_blank'>CDS</a>"
  var proteinLink = "<a href='/cgi-bin/geneSrt?project_id=" + projectId
    + "&ids=" + sourceId
    + "&ignore_gene_alias=" + ignore_gene_alias
    + "&type=protein&upstreamAnchor=Start&upstreamOffset=0&downstreamAnchor=End&downstreamOffset=0&endAnchor3=End&go=Get+Sequences' target='_blank'>protein</a>"
  var recordLink = '<a href="' + baseRecordUrl + '/gene/' + geneId + '">Gene Page</a>';

  var gbLink = "<a href='" + baseUrl + "index.html?data=" + dataRoot + "&loc=" + position + "'>JBrowse</a>";
  var orthomclLink = "<a href='http://orthomcl.org/cgi-bin/OrthoMclWeb.cgi?rm=sequenceList&groupac=" + orthomcl + "'>" + orthomcl + "</a>";

  // format into html table rows
  var rows = new Array();
    if (taxon != '') {rows.push(twoColRow('Species:', taxon))};
    if (sourceId != '') { rows.push(twoColRow('ID:', sourceId))};
    if (geneId != '') { rows.push(twoColRow('Gene ID:', geneId))};
    if (soTerm != '') { rows.push(twoColRow('Gene Type:', soTerm))};
    if (product != '') { rows.push(twoColRow('Description:', product))};

  var exon_or_cds = 'Exon:';

  if (soTerm =='Protein Coding') {
    exon_or_cds = 'CDS:';
  }

  if (loc != '') {
    rows.push(twoColRow(exon_or_cds, loc)) ;
  }
  if(utr != '') {
    rows.push(twoColRow('UTR:', utr));
  }
  // TO FIX for GUS4
  //  rows.push(twoColRow(GbrowsePopupConfig.saveRowTitle, getSaveRowLinks(projectId, sourceId)));
  if (soTerm =='Protein Coding' && aaseqid) {
    rows.push(twoColRow('Download:', cdsLink + " | " + proteinLink));
    if ( orthomcl != '') {
      rows.push(twoColRow('OrthoMCL', orthomclLink));
    }
  }
    if (geneId != '') { rows.push(twoColRow('Links:', gbLink + " | " + recordLink))};

  //tip.T_BGCOLOR = 'lightskyblue';
  //tip.T_TITLE = 'Annotated Gene ' + sourceId;
  return table(rows);
}


function gsnapUnifiedIntronJunctionTitle (track, feature, featureDiv) {
    var rows = new Array();
    //arrays
    var exps = feature.data["Exps"];
    var samples = feature.data["Samples"];
    var urs = feature.data["URS"];
    var isrpm = feature.data["ISRPM"];
    var nrs =  feature.data["NRS"];
    var percSamp = feature.data["PerMaxSample"]; 
    var isrCovRatio = feature.data["IsrCovRatio"]; 
    var isrAvgCovRatio = feature.data["IsrAvgCovRatio"]; 
    var normIsrCovRatio = feature.data["NormIsrCovRatio"]; 
    var normIsrAvgCovRatio = feature.data["NormIsrAvgCovRatio"]; 
    var isrpmExpRatio = feature.data["IsrpmExpRatio"]; 
    var isrpmAvgExpRatio = feature.data["IsrpmAvgExpRatio"]; 

    //attributes
    var totalScore = feature.data["TotalScore"]; 
    var intronPercent = feature.data["IntronPercent"]; 
    var intronRatio = feature.data["IntronRatio"]; 
    var matchesGeneStrand = feature.data["MatchesGeneStrand"]; 
    var isReversed = feature.data["IsReversed"]; 
    var annotIntron = feature.data["AnnotatedIntron"]; 
    var gene_source_id = feature.data["GeneSourceId"]; 

    var start = feature.data["start"];
    var end = feature.data["end"];

    var exp_arr = exps.split('|');
    var sample_arr = samples.split('|');
    var ur_arr = urs.split('|');
    var isrpm_arr = isrpm.split('|');
    var percSamp_arr = percSamp.split('|');
    var isrCovRatio_arr = isrCovRatio.split('|');
    var isrAvgCovRatio_arr = isrAvgCovRatio.split('|');
    var count = 0;
    var html;
    if(intronPercent) {
        html = "<table><tr><th>Experiment</th><th>Sample</th><th>Unique</th><th>ISRPM</th><th>ISR/Cov</th><th>% MAI</th></tr>";
    }
    else {
        html = "<table><tr><th>Experiment</th><th>Sample</th><th>Unique</th><th>ISRPM</th><th>ISR/AvgCov</th></tr>";
    }

    var maxRatio = [0,0,'sample here','experiment'];
    var sumIsrpm = 0;

    exp_arr.forEach(function(exp) {
        var sa = sample_arr[count].split(',');
        var ur = ur_arr[count].split(',');
        var isrpm = isrpm_arr[count].split(',');
        var rcs = isrCovRatio_arr[count].split(',');
        var rct = isrAvgCovRatio_arr[count].split(',');
        var ps = percSamp_arr[count].split(',');

        var i;
        for (i = 0; i < sa.length; i++) { 

            if(Number(isrpm[i]) > Number(maxRatio[0])) maxRatio = [ isrpm[i], intronPercent ? rcs[i] : rct[i], sa[i], exp, intronPercent ? rcs[i] : rct[i] ];
            sumIsrpm = sumIsrpm + Number(isrpm[i]);

            if(i == 0) {
                html = html + "<tr><td>"+ exp+ "</td><td>" + sa[i] + "</td><td>" + ur[i] + "</td><td>" + isrpm[i] + "</td>"; 
            } else {
                html = html + "<tr><td></td><td>" + sa[i] + "</td><td>" + ur[i] + "</td><td>" + isrpm[i] + "</td>"; 
            }
            if(intronPercent){
                html = html + "<td>" + rcs[i] + "</td><td>" + ps[i] + "</td></tr>";
            }else{
                html = html + "<td>" + rct[i] + "</td></tr>";
            }
        }
        count++;
    });
    html = html + "</table>";

    rows.push(twoColRow('<b>Intron Location:</b>', "<b>" + start + " - " + end + " (" + (end - start + 1) + ' nt)</b>'));
    rows.push(twoColRow('<b>Intron Spanning Reads (ISR):</b>', "<b>" + totalScore + "</b>" ));
    rows.push(twoColRow('<b>ISR per million (ISRPM):</b>', "<b>" + round(sumIsrpm, 2) + "</b>" ));
    if(intronPercent) rows.push(twoColRow('<b>Gene assignment:</b>', "<b>" + gene_source_id + (annotIntron === "Yes" ? " - annotated intron" : "") + "</b>"));
    if(intronPercent) rows.push(twoColRow('<b>&nbsp;&nbsp;&nbsp;% of Most Abundant Intron (MAI):</b>', "<b>" + intronPercent + "</b>"));
    rows.push(twoColRow('<b>Most abundant in:</b>', "<b>" + maxRatio[3] + " : " + maxRatio[2] + "</b>"));
    rows.push(twoColRow('<b>&nbsp;&nbsp;&nbsp;ISRPM (ISR /' + (annotIntron === 'Yes' ? ' gene coverage)' : ' avg coverage)') + '</b>', "<b>" + maxRatio[0] + " (" + maxRatio[1] +")</b>"));

    return table(rows) + html;
 }



function gsnapIntronWidthFromScore( feature ) {
    var sum = feature.data["TotalScore"]; 
    if(sum <= 4096) return 4;
    if(sum <= 16000) return 8;
    return 12;
}

function gsnapIntronHeightFromPercent ( feature ) {
    var goalHeight = gsnapIntronWidthFromScore(feature) * 2;

    var perc = feature.data["IntronPercent"]; 
    if(perc <= 5) return goalHeight + 3;
    if(perc <= 20) return goalHeight + 4;
    if(perc <= 60) return goalHeight + 5;
    if(perc <= 80) return goalHeight + 6;
    return goalHeight + 7;
}

function gsnapIntronColorFromStrandAndScore( feature ) {
    var isReversed = feature.data["IsReversed"]; 
    var sum = feature.data["TotalScore"]; 
    if(isReversed == 1) {
        if(sum <= 4) return 'rgb(255,219,219)';
        if(sum <= 16) return 'rgb(255,182,182)';
        if(sum <= 64) return 'rgb(255,146,146)';
        if(sum <= 256) return 'rgb(255,109,109)';
        if(sum <= 1024) return 'rgb(255,73,73)';
        return 'rgb(255,36,36)';   
    }
    else {
        if(sum <= 4) return 'rgb(219,219,255)';
        if(sum <= 16) return 'rgb(182,182,255)';
        if(sum <= 64) return 'rgb(146,146,255)';
        if(sum <= 256) return 'rgb(109,109,255)';
        if(sum <= 1024) return 'rgb(73,73,255)';
        return 'rgb(36,36,255)';   
    }
}


function colorSegmentByScoreFxn(feature) {
    var score = feature.data["score"];
    if (score > 60) return '#FF0000';
    if (score > 50) return '#FF8000';
    if (score > 40 ) return '#00FF00';
    if (score > 30 ) return '#0000FF';
    return '#000000';
}



function chipColor(feature) { 
    var a = feature.data["Antibody"];

    if(!a) {
      a = feature.data["immunoglobulin complex, circulating"];
    }
    
    var t = feature.data["Compound"];
    var r = feature.data["Replicate"];
    var g = feature.data['genotype information'];
    var l = feature.data['life cycle stage'];
    var anls = feature.data['sample_name'];

    if(anls == 'H4_schizonti_smoothed (ChIP-chip)') return '#D80000';
    if(anls == 'H4_trophozoite_smoothed (ChIP-chip)')  return '#006633';
    if(anls == 'H4_ring_smoothed (ChIP-chip)') return '#27408B';
    if(anls == 'H3K9ac_troph_smoothed (ChIP-chip)') return '#524818';

    if(/CenH3_H3K9me2/i.test(a)) return '#000080';
    if(/CenH3/i.test(a)) return '#B0E0E6';

    if (/wild_type/i.test(g) && (/H3K/i.test(a) || /H4K/i.test(a))) return '#0A7D8C';
    if (/sir2KO/i.test(g) && (/H3K/i.test(a) || /H4K/i.test(a))) return '#FF7C70';

    if(/H3K4me3/i.test(a) && r == 'Replicate 1') return '#00FF00';
    if(/H3K4me3/i.test(a) && r == 'Replicate 2') return '#00C896';
    if(/H3k4me1/i.test(a) && r == 'Replicate 1') return '#0033FF';
    if(/H3k4me1/i.test(a) && r == 'Replicate 2') return '#0066FF';


    if(/H3K9/i.test(a) && r == 'Replicate 1') return '#C86400';
    if(/H3K9/i.test(a) && r == 'Replicate 2') return '#FA9600';

    if(/DMSO/i.test(t)) return '#4B0082';
    if(/FR235222/i.test(t)) return '#F08080';

    if(r == 'replicate1') return '#00C800';
    if(r == 'replicate2') return '#FA9600';
    if(r == 'replicate3') return '#884C00';

    if(/early-log promastigotes/i.test(l)) return '#B22222';
    if(/stationary promastigotes/i.test(l)) return '#4682B4'; 

    if(/H3K4me3/i.test(a)) return '#00C800';
    if(/H3K9Ac/i.test(a)) return '#FA9600';
    if(/H3K9me3/i.test(a) ) return '#57178F';
    if(/H3/i.test(a) ) return '#E6E600';
    if(/H4K20me3/i.test(a)) return '#F00000';

    if(/SET8/i.test(a) && r == 'Replicate 1' ) return '#600000';
    if(/TBP1/i.test(a) && r == 'Replicate 1' ) return '#600000';
    if(/TBP2/i.test(a) && r == 'Replicate 1' ) return '#600000';
    if(/RPB9_RNA_pol_II/i.test(a) && r == 'Replicate 1' ) return '#600000';

    if(/SET8/i.test(a) && r == 'Replicate 2' ) return '#C00000';
    if(/TBP1/i.test(a) && r == 'Replicate 2' ) return '#C00000';
    if(/TBP2/i.test(a) && r == 'Replicate 2' ) return '#C00000';
    if(/RPB9_RNA_pol_II/i.test(a) && r == 'Replicate 2' ) return '#C00000';

   return '#B84C00';
}

function peakTitleChipSeq(track, feature, featureDiv) {
    var rows = new Array();

    var start = feature.data["start"];
    var end = feature.data["end"];

    rows.push(twoColRow('Start:', start));
    rows.push(twoColRow('End:', end));

    var ontologyTermToDisplayName = {'antibody' : 'Antibody', 
                                     'immunoglobulin complex, circulating' : 'Antibody',
                                     'genotype information' : 'Genotype', 
                                     'compound based treatment' : 'Treatment',
                                     'replicate' : 'Replicate',
                                     'life cycle stage' : 'Lifecycle Stage',
                                     'strain'   : 'Strain',
                                     'tag_count' : 'Normalised Tag Count',
                                     'fold_change' : 'Fold Change',
                                     'p_value' : 'P Value'};

    for (var key in ontologyTermToDisplayName) {
        var value = feature.data[key];
        var displayName = ontologyTermToDisplayName[key];
        if (value) {
            rows.push(twoColRow(displayName + ':', value));
        }
    }

    return table(rows);
}

function positionAndSequence( track, f, featDiv ) {
    container = dojo.create('div', { className: 'detail feature-detail feature-detail-'+track.name.replace(/\s+/g,'_').toLowerCase(), innerHTML: '' } );
    track._renderCoreDetails( track, f, featDiv, container );
    track._renderUnderlyingReferenceSequence( track, f, featDiv, container );
    return container;
}


function snpBgFromIsCodingAndNonSyn(feature) {
  var isCoding = feature.data["IsCoding"]; 
  var color = 'white';
  if (isCoding == 1 || /yes/i.test(isCoding)) {
    var nonSyn = feature.data["NonSyn"];
    var nonsense = feature.data["Nonsense"]; 
    color = nonsense == 1 ? 'red' : nonSyn == 1  ? 'blue' : 'lightblue'; 
  }
  return color; 
}


function snpTitle(track, feature, featureDiv) {
  var rows = new Array();
  var gene = feature.data["Gene"]; 
  var isCoding = feature.data["IsCoding"]; 
  var nonSyn = feature.data["NonSyn"]; 
  var nonsense = feature.data["Nonsense"]; 
  var rend = feature.data["rend"]; 
  var base_start = feature.data["base_start"];
  zoom_level = rend - base_start; 
  var position_in_CDS = feature.data["position_in_CDS"];
  var position_in_protein = feature.data["position_in_protein"];
  var reference_strain = feature.data["reference_strain"];
  var reference_aa = feature.data["reference_aa"];
  var gene_strand = feature.data["gene_strand"];
  var reference_na = feature.data["reference_na"];
  var major_allele = feature.data["major_allele"];
  var minor_allele = feature.data["minor_allele"];
  var major_allele_count = feature.data["major_allele_count"];
  var minor_allele_count = feature.data["minor_allele_count"];
  var major_allele_freq = feature.data["major_allele_freq"];
  var minor_allele_freq = feature.data["minor_allele_freq"];
  var major_product = feature.data["major_product"];
  var minor_product = feature.data["minor_product"];
  var source_id = feature.data["source_id"];
  var link_type = feature.data["type"];

  var start = feature.data["start"];

  var revArray = { 'A' : 'T', 'C' : 'G', 'T' : 'A', 'G' : 'C' };

  var link = "<a href='/a/app/record/" + link_type + "/" + source_id + "'>" + source_id + "</a>";
         
  var type = 'Non-coding';
  var refNA = gene_strand == -1 ? revArray[reference_na] : reference_na;

  var num_strains = major_allele_count + minor_allele_count;

  var testNA = reference_na;

  var refAAString = ''; 
  if (isCoding == 1 || /yes/i.test(isCoding)) {
     type = "Coding (" + (nonsense == 1 ? "nonsense)" : nonSyn ? "non-synonymous)" : "synonymous)");
     refAAString = "&nbsp;&nbsp;&nbsp;&nbsp;AA=" + reference_aa;
     minor_product = nonsense == 1 || nonSyn == 1 ? minor_product : major_product;
   }else{
     minor_product = '&nbsp';
   }


  rows.push(twoColRow("SNP:", link));
  rows.push(twoColRow("Location:", start));
  if(gene) rows.push(twoColRow("Gene:", gene));

  if (isCoding == 1 || /yes/i.test(isCoding)) {
      rows.push(twoColRow("Position&nbsp;in&nbsp;CDS", position_in_CDS));
      rows.push(twoColRow("Position&nbsp;in&nbsp;protein", position_in_protein));
  }

  rows.push(twoColRow("Type:", type));
  rows.push(twoColRow("Number of strains:", num_strains));
  rows.push(twoColRow(" ", 'NA&nbsp;&nbsp;&nbsp;'+ (isCoding == 1  ? 'AA&nbsp;&nbsp;&nbsp;(frequency)' : '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(frequency)')));
  rows.push(twoColRow(reference_strain + "&nbsp;(reference):", "&nbsp;" + refNA + "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp" + reference_aa));

  
  if(gene_strand == -1) major_allele = revArray[major_allele]; 
  if(gene_strand == -1) minor_allele = revArray[minor_allele];


  rows.push(twoColRow("Major Allele:", "&nbsp;" + major_allele + "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" + major_product + "&nbsp;&nbsp;&nbsp;&nbsp;(" + major_allele_freq + ")"));
  rows.push(twoColRow("Minor Allele:", "&nbsp;" + minor_allele + "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" + minor_product + "&nbsp;&nbsp;&nbsp;&nbsp;(" + minor_allele_freq + ")"));

  return table(rows);
}
