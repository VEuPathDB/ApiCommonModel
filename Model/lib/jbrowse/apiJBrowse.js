/* global Balloon, jQuery, Wdk, apidb */

/****** Table-building utilities ******/

function table(rows) {
  return '<table border="0">' + rows.join('') + '</table>';
}

function twoColRow(left, right) {
  return '<tr><td>' + left + '</td><td>' + right + '</td></tr>';
}

function twoColRowVAlign(left, right, valign) {
    return '<tr' + (valign != null ? ' valign=' + valign : '') + '><td>' + left + '</td><td>' + right + '</td></tr>'; }

function fiveColRow(one, two, three, four, five) {
  return '<tr><td>' + one + '</td><td>' + two + '</td><td>' + three + '</td><td>' + four + '</td><td>' + five + '</td></tr>';
}

/******  utilities ******/

function datasetLink(name, display) {
    return "<a  target='_blank' href='/a/processQuestion.do?questionFullName=DatasetQuestions.DatasetsByDatasetNames&dataset_name=" + name + "&questionSubmit=Get+Answer'>" + display + "</a>";
}

function datasetDescription(summary, trackSpecificText) {
    return "<p>" + trackSpecificText + "</p><p>" + summary + "</p>";
}



positionString = function(refseq, start, end, strand)  {
    var strandString = strand == 1 ? "(+ strand)" : "(- strand)";
    return refseq + ":" + start + ".." + end + " " + strandString;
}

positionNoStrandString = function(refseq, start, end)  {
    return refseq + ":" + start + ".." + end;
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


function interproColors (feature) {
    var colors = ["red", "green", "yellow", "blue", "khaki", "pink", "orange", "cyan", "purple", "black"];
    /**
       SQL> select name from sres.externaldatabase where row_alg_invocation_id = (select row_alg_invocation_id from sres.externaldatabase where name = 'SUPERFAMILY');
    **/
    var dbToColor = {'PRINTS' : 'red', 
                     'SUPERFAMILY' : 'green', 
                     'PRODOM' : 'yellow', 
                     'PFAM' : 'blue', 
                     'PROSITEPROFILES' : 'khaki', 
                     'INTERPRO' : 'pink', 
                     'PIRSF' : 'orange', 
                     'SMART' : 'cyan', 
                     'GENE3D' : 'purple', 
                     'TIGRFAM' : 'black'
                     };

    return dbToColor[feature.get("db")];
}


function exportPredTitle(track, feature) {
    var rows = new Array();
    var name = feature.get("domainname");
    rows.push(twoColRow('Name:', name));
    rows.push(twoColRow('Coordinates:', feature.get("start") + " .. " + feature.get("end")));
    return table(rows);
}

function lowcomplexitySegTitle (track, feature, featDiv) {
    var rows = new Array();
    var sequence = feature.get("sequence");

    rows.push(twoColRow('Coordinates:', feature.get("start") + " .. " + feature.get("end")));
    rows.push(twoColRow('Sequence:', sequence));
    return table(rows);
}



function blastpTitle (track, feature, featDiv) {
  var name = feature.get("name");
  var desc = feature.get("note");
  if(!desc) {
      desc = "<i>unavailable</i>";
  }
//  $desc =~ s/\001.*//;
    var rows = new Array();

    rows.push(twoColRow('Name:', name));
    rows.push(twoColRow('Description:', desc));
    rows.push(twoColRow('Expectation:', feature.get("expect")));
    rows.push(twoColRow('% Identical:', feature.get("percentidentity")));
    rows.push(twoColRow('% Positive:', feature.get("percentpositive")));
    rows.push(twoColRow('Coordinates:', feature.get("start") + " .. " + feature.get("end")));
    return table(rows);
}


function tmhmmTitle (track, feature, featDiv) {
    var desc = feature.get("topology");
    var rows = new Array();

    rows.push(twoColRow('Topology:', desc));
    rows.push(twoColRow('Coordinates:', feature.get("start") + " .. " + feature.get("end")));
    return table(rows);
}


function signalpTitle (track, feature, featDiv) {
    var rows = new Array();
    var d_score = feature.get("dscore");
    var signal_prob = feature.get("signalprob");
    var conclusion_score = feature.get("conclusionscore");
    var algorithm = feature.get("algorithm"); // 'SignalPhmm' or 'SignalPnn'
    algorithm = (algorithm == 'SignalPhmm') ? 'SP-HMM' : 'SP-NN';

    rows.push(twoColRow('Coordinates:', feature.get("start") + " .. " + feature.get("end")));
    rows.push(twoColRow('NN Conclusion Score:', conclusion_score));
    rows.push(twoColRow('NN D-Score:', d_score));
    rows.push(twoColRow('HMM Signal Probability:', signal_prob));
    rows.push(twoColRow('Algorithm:', algorithm));

    return table(rows);
}


function interproTitle (track, feature, featDiv) {
    var name = feature.get("name");
    var desc = feature.get("note");
    var db = feature.get("db");
    var url = feature.get("url");
    var evalue = feature.get("evalue");
    var interproId = feature.get("interproid");
    //  $evalue = sprintf("%.2E", $evalue);

    var rows = new Array();
    rows.push(twoColRow('Accession:', name));
    rows.push(twoColRow('Description:', desc));
    rows.push(twoColRow('Database:', db));
    rows.push(twoColRow('Coordinates:', feature.get("start") + " .. " + feature.get("end")));
    rows.push(twoColRow('Evalue:', evalue));
    rows.push(twoColRow('Interpro:', interproId));

    return table(rows);
}

function interproLink (feature) {
  var db = feature.data['Db'];
  var pi = feature.data['Pi'];

  var url;
  if(db == 'INTERPRO') { 
    url = "http://www.ebi.ac.uk/interpro/DisplayIproEntry?ac=" + pi;
  } else if( db == 'PFAM') { 
    url = "http://pfam.xfam.org/family?acc=" + pi;
  } else if( db == 'PRINTS') {
    url = "http://umber.sbs.man.ac.uk/cgi-bin/dbbrowser/sprint/searchprintss.cgi?prints_accn=" + pi + "&display_opts=Prints&category=None&queryform=false&regexpr=off";
  } else if( db == 'PRODOM') {
    url = "http://prodom.prabi.fr/prodom/current/cgi-bin/request.pl?question=DBEN&query=" + pi;
  } else if( db == 'PROFILE') {
    url = "http://www.expasy.org/prosite/" + pi;
  } else if( db == 'SMART') {
    url = "http://smart.embl-heidelberg.de/smart/do_annotation.pl?ACC=" + pi + "&BLAST=DUMMY"; 
  } else if( db == 'SUPERFAMILY') { 
    url = "http://supfam.org/SUPERFAMILY/cgi-bin/scop.cgi?ipid=" + pi;
  } else {
    url = "http://www.ebi.ac.uk/interpro/ISearch?query=" + pi + "&mode=all";
  }

  return url;
}



/****** Pop-up functions for various record types ******/

function microsatelliteTitle(track, feature, featDiv) {
    var accessn      = feature.get("name");
    var genbankLink  = "<a target='_blank' href='http://www.ncbi.nlm.nih.gov/sites/entrez?db=unists&cmd=search&term=" + accessn + "'>" + accessn + "</a>";
    var start        = feature.get("startm");
    var end         = feature.get("end");
    var length       = end - start + 1;
    var name        = feature.data['Name'];
    var sequenceId       = feature.data['SequenceId'];

    container = dojo.create('div', { className: 'detail feature-detail feature-detail-'+track.name.replace(/\s+/g,'_').toLowerCase(), innerHTML: '' } );

    var coreDetails = dojo.create('div', { className: 'core' }, container );

    var fmt = dojo.hitch( track, 'renderDetailField', coreDetails );
    coreDetails.innerHTML += '<h2 class="sectiontitle">Microsatellite</h2>';

    fmt( 'Name', name, feature );
    fmt( 'Genbank Accession', accessn, feature );
    fmt('Position', positionNoStrandString(track.refSeq.name, feature.get("startm"), feature.get("end")) ,feature);
    fmt( 'ePCR Product Size', length, feature);

    track._renderUnderlyingReferenceSequence( track, feature, featDiv, container );
    return container;

}



// Gene title
function gene_title (tip, projectId, sourceId, chr, cds, soTerm, product, taxon, utrFive, utrThree, position, orthomcl, geneId, dataRoot, baseUrl, baseRecordUrl, aaseqid, feature ) {

  // In ToxoDB, sequences of alternative gene models have to be returned
  var ignore_gene_alias = 0;
  if (projectId == 'ToxoDB') {
    ignore_gene_alias = 1;
  }
  var orgAbbrev = feature.get("orgabbrev");
  var dataRootRegex = /\/jbrowse\/.+Tracks\//;
    dataRoot = dataRoot.replace(dataRootRegex, "/jbrowse/tracks/");

  // expand minimalist input data
  var cdsLink = "<a target='_blank' href='/cgi-bin/geneSrt?project_id=" + projectId
    + "&ids=" + sourceId
    + "&ignore_gene_alias=" + ignore_gene_alias
    + "&type=CDS&upstreamAnchor=Start&upstreamOffset=0&downstreamAnchor=End&downstreamOffset=0&go=Get+Sequences' target='_blank'>CDS</a>"
  var proteinLink = "<a target='_blank' href='/cgi-bin/geneSrt?project_id=" + projectId
    + "&ids=" + sourceId
    + "&ignore_gene_alias=" + ignore_gene_alias
    + "&type=protein&upstreamAnchor=Start&upstreamOffset=0&downstreamAnchor=End&downstreamOffset=0&endAnchor3=End&go=Get+Sequences' target='_blank'>protein</a>"
  var recordLink = '<a target="_blank" href="' + baseRecordUrl + '/gene/' + geneId + '">Gene Page</a>';

    baseUrl = baseUrl.replace(/\/$/,'');
    var gbLink = "<a target='_blank' href='" + baseUrl + ".jsp?loc=" + position + "&data=/a/service/jbrowse/tracks/" + orgAbbrev +  "&tracks=gene" + "'>JBrowse</a>";

  var orthomclLink = "<a target='_blank' href='http://orthomcl.org/cgi-bin/OrthoMclWeb.cgi?rm=sequenceList&groupac=" + orthomcl + "'>" + orthomcl + "</a>";

  // format into html table rows
  var rows = new Array();
    if (taxon != null) {rows.push(twoColRow('Species:', taxon))};
    if (sourceId != null) { rows.push(twoColRow('ID:', sourceId))};
    if (geneId != null) { rows.push(twoColRow('Gene ID:', geneId))};
    if (soTerm != null) { rows.push(twoColRow('Gene Type:', soTerm))};
    if (product != null) { rows.push(twoColRow('Description:', product))};

  var exon_or_cds = 'Exon:';

  if (soTerm =='Protein Coding') {
    exon_or_cds = 'CDS:';
  }

  if(utrFive != null && utrFive != '') {
      rows.push(twoColRowVAlign('5\' UTR:', utrFive, 'top'));
  }

  if(cds != null) {
      rows.push(twoColRowVAlign(exon_or_cds, cds, 'top'));
  }

  if(utrThree != null && utrThree != '') {
      rows.push(twoColRowVAlign('3\' UTR:', utrThree, 'top'));
  }
  // TO FIX for GUS4
  //  rows.push(twoColRow(GbrowsePopupConfig.saveRowTitle, getSaveRowLinks(projectId, sourceId)));
  if (soTerm =='Protein Coding' && aaseqid) {
    rows.push(twoColRow('Download:', cdsLink + " | " + proteinLink));
    if ( orthomcl != null) {
      rows.push(twoColRow('OrthoMCL', orthomclLink));
    }
  }
    if (geneId != null) { rows.push(twoColRow('Links:', gbLink + " | " + recordLink))};

  //tip.T_BGCOLOR = 'lightskyblue';
  //tip.T_TITLE = 'Annotated Gene ' + sourceId;
  return table(rows);
}


function gsnapUnifiedIntronJunctionTitle (track, feature, featureDiv) {
    var rows = new Array();
    //arrays
    var exps = feature.get("exps");
    var samples = feature.get("samples");
    var urs = feature.get("urs");
    var isrpm = feature.get("isrpm");
    var nrs =  feature.get("nrs");
    var percSamp = feature.get("permaxsample"); 
    var isrCovRatio = feature.get("isrcovratio"); 
    var isrAvgCovRatio = feature.get("isravgcovratio"); 
    var normIsrCovRatio = feature.get("normisrcovratio"); 
    var normIsrAvgCovRatio = feature.get("normisravgcovratio"); 
    var isrpmExpRatio = feature.get("isrpmexpratio"); 
    var isrpmAvgExpRatio = feature.get("isrpmavgexpratio"); 

    //attributes
    var totalScore = feature.get("totalscore"); 
    var intronPercent = feature.get("intronpercent"); 
    var intronRatio = feature.get("intronratio"); 
    var matchesGeneStrand = feature.get("matchesgenestrand"); 
    var isReversed = feature.get("isreversed"); 
    var annotIntron = feature.get("annotatedintron"); 
    var gene_source_id = feature.get("genesourceid"); 

    var start = feature.get("startm");
    var end = feature.get("end");

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
    var sum = feature.get("totalscore"); 
    if(sum <= 4096) return 2;
    if(sum <= 16000) return 3;
    return 4;
}

function gsnapIntronHeightFromPercent ( feature ) {
    var goalHeight = gsnapIntronWidthFromScore(feature) * 2;

    var perc = feature.get("intronpercent"); 
    if(perc <= 5) return goalHeight + 2;
    if(perc <= 20) return goalHeight + 3;
    if(perc <= 60) return goalHeight + 4;
    if(perc <= 80) return goalHeight + 5;
    return goalHeight + 6;
}


function unifiedPostTranslationalModColor(feature) {
  var ontology = feature.data['ModificationType'];

  if(/phosphorylation_site/i.test(ontology)) {
    return 'dodgerblue';
  } else if (/modified_L_cysteine/i.test(ontology)) {
    return 'deepskyblue';
  } else if (/iodoacetamide_derivatized_residue/i.test(ontology)) {
    return 'blueviolet';
  } else if (/modified_L_methionine/i.test(ontology)) {
    return 'steelblue';
  }
  return 'blue';
}

function unifiedPostTranslationalModTitle(track, feature) {
    var experiments = feature.data['Experiments'];
    var samples = feature.data['Samples'];

    var pepSeqs = feature.data['PepSeqs'];
    var pepNaFeatIds = feature.data['PepAAFeatIds'];
    var mscounts = feature.data['MSCounts'];

    var residueLocations = feature.data['ResidueLocs'];
    var ontologys = feature.data['Ontologys'];

    var aaStartMins = feature.data['AAStartMins'];

    var location = feature.get("end");
    var featureName = feature.get("name");

    var rows = new Array();

    var hash = {};

    var exps = experiments.split('|');
    var smpls = samples.split('|');
    var pepseqs = pepSeqs.split('|');
    var pepNaFeatIds = pepNaFeatIds.split('|');

    var mscts = mscounts.split('|');
    var onts = ontologys.split('|');
    var resLocs = residueLocations.split('|');
    var aaStartMins = aaStartMins.split('|');

    for(var i = 0; i < exps.length; i++) {
        var expt = exps[i];
        var sample = smpls[i];
        var pepSeq = pepseqs[i];
        var pepNaFeatId = pepNaFeatIds[i];
        var msct = mscts[i];
        var allAaMin = aaStartMins[i];
        var allOnt = onts[i];
        var allResidueLoc = resLocs[i];
        
        var resLocsArr = allResidueLoc.split(',');
        var ontArr = allOnt.split(',');
        var aaMinArr = allAaMin.split(',');

        var match = false;
        resLocsArr.forEach(function(e) {
            if(e == location) match = true ;
        });

        if(match) {
            if(!hash[expt]) {
                hash[expt] = {};
            }
            if(!hash[expt][sample]) {
                hash[expt][sample] = {};
            }
            if(!hash[expt][sample][pepNaFeatId]) {
                hash[expt][sample][pepNaFeatId] = [];
            }
            hash[expt][sample][pepNaFeatId].push({'pepSeq' :  pepSeq, 'mscount' : msct, 'residue_locations' : resLocsArr, 'ontology' : ontArr, 'aa_start' : aaMinArr});
        }
    }

    rows.push(twoColRow('Residue: ', featureName));


   for(var e in hash) {
       rows.push(twoColRow('===========', "======================="));
       rows.push(twoColRow('Experiment: ', e));

      for(var s in hash[e]) {
          rows.push(twoColRow('Sample: ', s));

        for(var pi in hash[e][s]) {
            hash[e][s][pi].forEach(function(peps){
                
                var pepSequence = peps['pepSeq'];
                var msCount = peps['mscount'];

                var residueLocations = peps['residue_locations'];
                var ontology = peps['ontology']
                var aaStarts = peps['aa_start'];

                if(residueLocations) {

                    var offset = 1;

                    // residue locations are sorted in sql
                    for(var i = 0; i < residueLocations.length; i++) {
                        var rl = residueLocations[i];
                        var type = ontology[i];
                        var aaStart = aaStarts[i];

                        var loc = rl - aaStart + 1 + offset;


                        if(/phosphorylation/i.test(type)) {
                            pepSequence = [pepSequence.slice(0, loc), '*', pepSequence.slice(loc)].join('');
                        }
                        if(/methionine/i.test(type)) {
                            pepSequence = [pepSequence.slice(0, loc), '#', pepSequence.slice(loc)].join('');

                        }
                        if(/cysteine/i.test(type)) {
                            pepSequence = [pepSequence.slice(0, loc), '^', pepSequence.slice(loc)].join('');
                        }
                        
                        offset = offset + 1;
                    }
                }
                    rows.push(twoColRow('Sequence: ', pepSequence + ' (' + msCount + ')'));
            
                });
        }
     }
   }
  
  return table(rows);

}


function syntenyColor( feature ) {

    if(feature.get("syntype") == "span") {
        var chr = feature.get("chromosome");
        var col = feature.get("chrcolor");
        if(col) return col;
        if(feature.get("strand") == 1) return "orange" ;
        return "darkseagreen";
    }

    if(feature.get("type") == 'minispan') {
        if(feature.get("scale") > 1.5) {
            return "cyan";
        }
        if(feature.get("scale") < -1.5) {
            return "yellow";
        }
    }

/**
    if(feature.get("type") == 'exon') {
        var scale = (feature._parent.get("end") - feature._parent.get("start")) / (Number(feature._parent.get("end")) - Number(feature._parent.get("start")));        

        if(scale < 0.25) {
            return(feature.get("strand") == 1 ? "skyblue" :  "pink")
        }
    }
**/
    return feature.get("strand") == 1 ? "#000080" : "#aa3311"         
}




function gsnapIntronColorFromStrandAndScore( feature ) {
    var isReversed = feature.get("isreversed"); 
    var sum = feature.get("totalscore"); 
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
    var score = feature.get("score");
    if (score > 60) return '#FF0000';
    if (score > 50) return '#FF8000';
    if (score > 40 ) return '#00FF00';
    if (score > 30 ) return '#0000FF';
    return '#000000';
}



function chipColor(feature) { 
    var a = feature.get("antibody");

    if(!a) {
      a = feature.data["immunoglobulin complex, circulating"];
    }
    
    var t = feature.get("compound");
    var r = feature.get("replicate");
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

    var start = feature.get("startm");
    var end = feature.get("end");

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
  var isCoding = feature.get("iscoding"); 
  var color = '#ffe135';
  if (isCoding == 1 || /yes/i.test(isCoding)) {
    var nonSyn = feature.get("nonsyn");
    var nonsense = feature.get("nonsense"); 
    color = nonsense == 1 ? 'red' : nonSyn == 1  ? 'blue' : 'lightblue'; 
  }
  return color; 
}


function snpTitle(track, feature, featureDiv) {
  var rows = new Array();
  var gene = feature.get("gene"); 
  var isCoding = feature.get("iscoding"); 
  var nonSyn = feature.get("nonsyn"); 
  var nonsense = feature.get("nonsense"); 
  var rend = feature.get("rend"); 
  var base_start = feature.get("base_start");
  zoom_level = rend - base_start; 
  var position_in_CDS = feature.get("position_in_cds");
  var position_in_protein = feature.get("position_in_protein");
  var reference_strain = feature.get("reference_strain");
  var reference_aa = feature.get("reference_aa");
  var gene_strand = feature.get("gene_strand");
  var reference_na = feature.get("reference_na");
  var major_allele = feature.get("major_allele");
  var minor_allele = feature.get("minor_allele");
  var major_allele_count = feature.get("major_allele_count");
  var minor_allele_count = feature.get("minor_allele_count");
  var major_allele_freq = feature.get("major_allele_freq");
  var minor_allele_freq = feature.get("minor_allele_freq");
  var major_product = feature.get("major_product");
  var minor_product = feature.get("minor_product");
  var source_id = feature.get("source_id");
  var link_type = feature.get("type");

  var start = feature.get("startm");
  var end = feature.get("end");

  var revArray = { 'A' : 'T', 'C' : 'G', 'T' : 'A', 'G' : 'C' };

  var link = "<a target='_blank' href='/a/app/record/" + link_type + "/" + source_id + "'>" + source_id + "</a>";
         
  var type = 'Non-coding';
  var refNA = gene_strand == -1 ? revArray[reference_na] : reference_na;

  var num_strains = major_allele_count + minor_allele_count;

  var testNA = reference_na;

  var refAAString = ''; 
  if (isCoding == 1 || /yes/i.test(isCoding)) {
     type = "Coding (" + (nonsense == 1 ? "nonsense)" : nonSyn == 1 ? "non-synonymous)" : "synonymous)");
     refAAString = "&nbsp;&nbsp;&nbsp;&nbsp;AA=" + reference_aa;
     minor_product = nonsense == 1 || nonSyn == 1 ? minor_product : major_product;
   }else{
     minor_product = '&nbsp';
   }


  rows.push(twoColRow("SNP:", link));
  rows.push(twoColRow("Location:", end));
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




function spliceSiteTitle(track, feature, featureDiv) {
  var rows = new Array();
  var start = feature.get("startm");

  var gene = feature.get("gene_id");
  var utr_len = feature.get("utr_length");
  if (!utr_len){
    utr_len = "N/A (within CDS)";
  }
  var note = "The overall count is the sum of the count per million for each sample.";

  var samples = feature.get("sample_name");
  var ctpm = feature.get("count_per_mill");
 
  var isUniq = feature.get("is_unique");
  var mismatch = feature.get("avg_mismatches");

  var html = "<table><tr><th>Sample</th><th>Count per million</th></tr>";
  var count = 0;

  var samples_arr = samples.split(',');
  var ct_arr = ctpm.split(',');
  var arrSize = samples_arr.length;
  for (var i = 0; i < arrSize; i++) {
    html = html + "<tr><td>"  + samples_arr[i] + "</td><td>" + ct_arr[i] + "</td></tr>";
    count = count + Number(ct_arr[i]);
  }
  html = html + "</table>";

  rows.push(twoColRow("Location:", start));
  if (gene) {rows.push(twoColRow("Gene ID:", gene))};
  rows.push(twoColRow("UTR Length:", utr_len));
  rows.push(twoColRow("Count:", count));
  rows.push(twoColRow("Note:", note));

  rows.push(twoColRow(" ", html));
  
  return table(rows);
}


function colorSpliceSite(feature) {
  var rows = new Array();
  var samples = feature.get("sample_name");
  var ctpm = feature.get("count_per_mill");
  var strand = feature.get("strand");

  var samples_arr = samples.split(',');
  var ct_arr = ctpm.split(',');
  var arrSize = samples_arr.length;
  var count = 0;

  for (var i = 0; i < arrSize; i++) {
    count = count + Number(ct_arr[i]);
  }

  if (strand == 1){
    if (count < 2) return 'lightskyblue';
    if (count < 10) return 'cornflowerblue';
    if (count < 100) return 'blue';
    if (count < 1000) return 'navy';
    return 'black';
  }
  if (strand == 0){
    if (count < 2) return '#FFCCCC';
    if (count < 10) return 'pink';
    if (count < 100) return 'orange';
    if (count < 1000) return 'tomato';
    return 'firebrick';
  }
}



function gffKirkland(track, feature, featureDiv) {
  var rows = new Array();

  var motif = feature.get("target");
  motif = motif.replace(/Motif:|,|[0-9*]/gi, "");
 
  rows.push(twoColRow('Motif: ', motif))
  rows.push(twoColRow('Score: ', feature.get("score")))

  return table(rows);
}

function repeatFamily(track, feature, featureDiv) {
  var rows = new Array();

  rows.push(twoColRow('Family:', feature.get("family") ));
  rows.push(twoColRow('Position:', positionNoStrandString(track.refSeq.name, feature.get("startm"), feature.get("end"))));

  return table(rows);
}

function transposon(track, feature, featureDiv) {
  var rows = new Array();


    rows.push(twoColRow('Transposable Element:', feature.get("name") ));
    rows.push(twoColRow('Name:', feature.get("te_name") ));
    rows.push(twoColRow('Size:', feature.get("alignlength") ));
    rows.push(twoColRow('Position:', positionNoStrandString(track.refSeq.name, feature.get("startm"), feature.get("end"))));

    return table(rows);
}

function bindingSiteTitle(track, feature, featureDiv) {

    var name = feature.get("name");
    var start = feature.get("startm");
    var end  = feature.get("end");
    var strand  = feature.get("strand");
    var score = feature.get("score");
    var sequence = feature.get("sequence");

  if(strand === '+1') {
      strand = 'FORWARD';
  }
  else {
      strand = 'REVERSE';
  }

    var link = "<a target='_blank' href='/a/images/pf_tfbs/"+ name + ".png'><img src='/a/images/pf_tfbs/" + name + ".png'  height='140' width='224' align=left/></a>";
    var rows = new Array();
  rows.push(twoColRow('Name:', name));
  rows.push(twoColRow('Start:', start));
  rows.push(twoColRow('End:', end));
  rows.push(twoColRow('Strand:', strand));
  rows.push(twoColRow('Score:', score));
  rows.push(twoColRow('Sequence:', sequence));
  rows.push(twoColRow('Click logo for larger image:', link));
   
    return table(rows);

}

function colorForBindingSitesByPvalue(feature){
    var strand  = feature.get("strand");
    var pvalue = feature.get("score");


if(strand == '+1') {
        if(pvalue <= 1e-5) return 'mediumblue';
        if(pvalue <= 5e-5) return 'royalblue';
        if(pvalue <= 1e-4) return 'dodgerblue';
        return 'skyblue';
    }
    else {
        if(pvalue <=1e-5) return 'darkred';
        if(pvalue <= 5e-5) return 'crimson';
        if(pvalue <= 1e-4) return 'red';
        return 'tomato';
    }
    
}

function changeScaffoldType(feature) {
    if(feature.data['Type'] == 'fgap') {
        return 'JBrowse/View/FeatureGlyph/Segments'; 
    }
    return 'JBrowse/View/FeatureGlyph/Box';
}

function scaffoldColor(feature) {
    var orient = feature.get("strand");
    if (orient == 1) {
      return "orange";
    } 
    if (orient == -1) {
        return "darkseagreen";
    }
    return "red";
}

function scaffoldHeight(feature) {
    if(feature.data['type'] == 'gap' || feature.data['Type'] == 'fgap') {
        return 25;
    }

    return 1;
}


function scaffoldDetails(track, feature) {
    var rows = new Array();

    if(feature.get("type") == 'fgap') {
        feature.get("subfeatures").forEach(function(element) {
            rows.push(twoColRow('Gap Position:', positionNoStrandString(track.refSeq.name, element.get("startm"), element.get("end"))));
        });

    }
    else {
        rows.push(twoColRow('Name:', feature.get("name")));
        rows.push(twoColRow('Position:', positionString(track.refSeq.name, feature.get("startm"), feature.get("end"), feature.get("strand"))));
    }
   
    return table(rows);
}


function genericEndFeatureTitle(track, feature, trackType) { 
  var start = feature.get("startm");
  var end  = feature.get("end");
  var length = end - start + 1;
  var cname = feature.get("name");

  var rows = new Array();

  rows.push(twoColRow("End-Sequenced " + trackType + ":", cname));
  rows.push(twoColRow('Clone Size:', length));
  rows.push(twoColRow('Clone Location:', start + ".." + end));
  rows.push(twoColRow('<hr>', '<hr>'));

  var count = 0;
  feature.get("subfeatures").forEach(function(element) {

    count = count + 1;
    var name  = element.data['name']; 
    var start = element.get("startm"); 
    var end = element.data['end']; 
    var pct = element.get("pct");
    var score = element.get("score");

    rows.push(twoColRow(trackType + ' End:', name));
    rows.push(twoColRow('Location:', start + ".." + end));
    rows.push(twoColRow('Percent Identity:', pct + " %"));
    rows.push(twoColRow('Score:', score));
    if(count % 2) rows.push(twoColRow('<hr>', '<hr>'));
  });
   return table(rows);
}

function arrayElementTitle (track, feature, type) { 
  var rows = new Array();

  rows.push(twoColRow("Name:" , feature.get("sourceid")));
  rows.push(twoColRow("Probe Type:" , type));
  rows.push(twoColRow("Position:" , positionNoStrandString(track.refSeq.name, feature.get("startm"), feature.get("end"))));

  return table(rows);
}

function gene_title_gff (tip, sourceId, fiveUtr, cdss, threeUtr, totScore, fiveSample, fiveScore, threeSample, threeScore) {

  // format into html table rows
  var rows = new Array();
    if (sourceId != null) { rows.push(twoColRow('ID:', sourceId))};
    if (totScore != null && totScore != 'NaN') { rows.push(twoColRow('Score:', totScore))};

  if(fiveUtr != null && fiveUtr != '') {
      rows.push(twoColRowVAlign('5\' UTR:', fiveUtr, 'top'));
  }
  if(cdss != null) {
      rows.push(twoColRowVAlign('CDS:', cdss, 'top'));
  }

  if(threeUtr != null && threeUtr != '') {
      rows.push(twoColRowVAlign('3\' UTR:', threeUtr, 'top'));
  }

    //samples and scores for models
    if (fiveSample != null) { rows.push(twoColRow('5\' UTR Samples:', fiveSample))};
    if (fiveScore != null) { rows.push(twoColRow('5\' UTR Scores:', fiveScore))};
    if (threeSample != null) { rows.push(twoColRow('3\' UTR Samples:', threeSample))};
    if (threeScore != null) { rows.push(twoColRow('3\' UTR Scores:', threeScore))};
    
  return table(rows);
}

function gffGeneFeatureTitle(track, feature) { 
    
    var sourceId = feature.get("name");
    var strand = feature.get("strand");

    var model = orientAndGetUtrsAndCDS(strand,feature.get("subfeatures"));

    //  CRAIG samples and scores
    var five_sample = feature.get("fiveutr_sample");
    var five_score = feature.get("fiveutr_score");
    var three_sample = feature.get("threeutr_sample");
    var three_score = feature.get("threeutr_score");
    
    var totScore = feature.get("score");

    return gene_title_gff(this,sourceId,model[0],model[1],model[2],totScore,five_sample,five_score,three_sample,three_score);

}



//will return oriented 5pUtr, cds and 3pUtr
function orientAndGetUtrsAndCDS(strand, exons){
    var utr = exons.filter(function(sf) { return sf.get("type") === "UTR" });
    var cds = exons.filter(function(sf) { return sf.get("type") === "CDS" });
    var ret = new Array();
    if(strand == '-1'){
        utr.reverse();
        cds.reverse();
        ret.push(getFiveUtr(strand,utr,cds[0].get("end")).map(x => ('complement(' + x.get("end") + '..' + x.get("startm") + ')')).join("</br>"));
        ret.push(cds.map(x => ('complement(' + x.get("end") + '..' + x.get("startm") + ')')).join("</br>"));
        ret.push(getThreeUtr(strand,utr,cds[cds.length-1].get("startm")).map(x => ('complement(' + x.get("end") + '..' + x.get("startm") + ')')).join("</br>"));
//        ret.push("complement(" + (cds.length > 1 ? "join(" : "") + cds.map(x => (x.get("end") + '..' + x.get("startm"))).join(", ") + (cds.length > 1 ? ")" : "") + ")");
    }else{
        ret.push(getFiveUtr(strand,utr,cds[0].get("startm")).map(x => (x.get("startm") + ".." + x.get("end"))).join("</br>"));
        ret.push(cds.map(x => (x.get("startm") + ".." + x.get("end"))).join("</br>"));
        ret.push(getThreeUtr(strand,utr,cds[cds.length-1].get("end")).map(x => (x.get("startm") + ".." + x.get("end"))).join("</br>"));
//        ret.push((cds.length > 1 ? "join(" : "") + cds.map(x => (x.get("startm") + ".." + x.get("end"))).join(", ") + (cds.length > 1 ? ")" : ""));
    }
    return(ret);
}

function getFiveUtr(strand,utr,cdsStart){
    var five = new Array();
    if(strand == '-1'){
        five = utr.filter(function(sf) { return sf.get("startm") >= cdsStart });
    }else{
        five = utr.filter(function(sf) { return sf.get("end") <= cdsStart });
    }
    return(five);
}

function getThreeUtr(strand,utr,cdsEnd){
    var three = new Array();
    if(strand == '-1'){
        three = utr.filter(function(sf) { return sf.get("end") <= cdsEnd });
    }else{
        three = utr.filter(function(sf) { return sf.get("startm") >= cdsEnd });
    }
    return(three);
}

function haplotypeColor(feature) { 
  boundary = feature.data['Boundary'];
  if(boundary == 'Liberal') {
      return 'darkseagreen';
  }
  return 'darkgreen';
}


function haplotypeTitle(track, feature, featureDiv) {
    var accessn = feature.get("name");
    var start = feature.get("startm");
    var end = feature.get("end");
    var length = end - start + 1;
    var boundary = feature.data['boundary'];
    var name = feature.data['Name'];
    var start_max = feature.data['start_max'];
    var start_min = feature.data['start_min'];
    var end_min = feature.data['end_min'];
    var end_max = feature.data['end_max'];
    var sequenceId = feature.data['SequenceId'];

    var libContlink = "<a target='_blank' href='/a/showQuestion.do?questionFullName=GeneQuestions.GenesByLocation&value%28sequenceId%29=" + sequenceId + "&value%28organism%29=Plasmodium+falciparum&value%28end_point%29=" + end_max + "&value%28start_point%29=" + start_min + "&weight=10'>Contained Genes</a>";
    var consrvContlink = "<a target='_blank' href='/a/showQuestion.do?questionFullName=GeneQuestions.GenesByLocation&value%28sequenceId%29=" + sequenceId + "&value%28organism%29=Plasmodium+falciparum&value%28end_point%29=" + end_min + "&value%28start_point%29=" + start_max + "&weight=10'>Contained Genes</a>";
    var libAssoclink = "<a target='_blank' href='/a/showQuestion.do?questionFullName=GeneQuestions.GenesByEQTL_Segments&value%28lod_score%29=1.5&value%28end_point_segment%29=" + end_max + "&value%28pf_seqid%29=" + sequenceId + "&value%28liberal_conservative%29=Liberal+Locations&value%28start_point%29=" + start_min + "&weight=10'>Associated Genes</a>";
    var consrvAssoclink = "<a target='_blank' href='/a/showQuestion.do?questionFullName=GeneQuestions.GenesByEQTL_Segments&value%28lod_score%29=1.5&value%28end_point_segment%29=" + end_min + "&value%28pf_seqid%29=" + sequenceId + "&value%28liberal_conservative%29=Conservative+Locations&value%28start_point%29=" + start_max + "&weight=10'>Associated Genes</a>";

    var rows = new Array();
    rows.push(twoColRow('Name (Centimorgan value appended):', name));
    rows.push(twoColRow('Sequence Id:', sequenceId));
    rows.push(twoColRow('Liberal Start-End:', start_min + ".." + end_max + "  (" + libAssoclink + ", " + libContlink + ")"));
    rows.push(twoColRow('Conservative Start-End:', start_max + ".." + end_min + "   (" + consrvAssoclink + ", " + consrvContlink + ")"));
    rows.push(twoColRow('Liberal Length:', Math.abs(end_max - start_min)));
    rows.push(twoColRow('Conservative Length:', Math.abs(end_min - start_max)));

    return table(rows);
}


function syntenyTitle(track, feature, featureDiv) {
    var syntype = feature.get("syntype");
    if(syntype == 'span') {
        return synSpanTitle(track, feature);
    } 
    else {
        return synGeneTitle(track, feature);
    }
}

  
function synGeneTitle(track, feature) {

    var sourceId = feature.get("name");
    var taxon = feature.get("taxon");
    var orgAbbrev = feature.get("orgabbrev");
    var desc = feature.get("note");

    var soTerm = feature.get("soterm");
    var orthomclName = feature.get("orthomcl_name");
    var isPseudo = feature.get("ispseudo");
    var isPseudoString = isPseudo == 1 ? "Pseudogenic " : "";

    soTerm = soTerm.replace(/\_/g,' ')
        .replace(/\b(\w)/g, function(x) {
            return x.toUpperCase();
        }) + isPseudoString;

    var seqId = feature.get("contig");
    var start = Number(feature.get("genestart"));
    var end = Number(feature.get("geneend"));
    var window = 500; // width on either side of gene
    var linkStart = start - window;
    var linkStop = end + window;

    var trunc = feature.get("truncated");
    var truncString = "";
    if(trunc) truncString =  " (truncated by syntenic region to " + trunc + ")";
    var location = seqId + ": " +  start + " - " + end + truncString;

    var linkPosition = seqId + ":" + linkStart + ".." + linkStop;
    var highlightPosition = seqId + ":" + start + ".." + end;
    var baseRecordUrl = "/a/app/record";

    var dataRoot = track.browser.config.dataRoot;
    var baseUrl = track.browser.config.baseUrl;
    baseUrl = baseUrl.replace(/\/$/,'');

    var recordLink = '<a target="_blank" href="' + baseRecordUrl + '/gene/' + sourceId + '">Gene Page</a>';

    var gbLink = "<a target='_blank' href='" + baseUrl + ".jsp?loc=" + linkPosition + "&data=/a/service/jbrowse/tracks/" + orgAbbrev +  "&tracks=gene" + "&highlight=" + highlightPosition + "'>JBrowse</a>";


    // format into html table rows
    var rows = new Array();
    rows.push(twoColRow('Gene:', sourceId));
    rows.push(twoColRow('Species:', taxon));
    rows.push(twoColRow('Gene Type:', soTerm));
    rows.push(twoColRow('Description:', desc));
    rows.push(twoColRow('Location:', location));
    //  TODO? rows.push(twoColRow(GbrowsePopupConfig.saveRowTitle, getSaveRowLinks(projectId, sourceId)));
    rows.push(twoColRow('Links:', gbLink + ' | ' + recordLink));

    if (soTerm == 'Protein Coding') {
        rows.push(twoColRow('OrthoMCL', orthomclName));
    }

    return table(rows);
}

function synSpanTitle(track, feature) {
    var chr = track.refSeq.name;
    var strand = feature.get("strand") == 1 ? "no" : "yes";
    var refStart = feature.get("refstart");
    var refEnd = feature.get("refend");
    var refLength = refEnd - refStart;
    var synStart = feature.get("synstart");
    var synEnd = feature.get("synend");
    var synLength = synEnd - synStart;
    var contigLength = feature.get("contiglength");
    var refContigLength = feature.get("refcontiglength");
    var contigSourceId = feature.get("contig");
    var chromosome = feature.get("chromosome");
    var taxon = feature.get("taxon");
    var isRef = ( chr == contigSourceId ) ? 1 : 0;

    var rows = new Array();

    if(chromosome) rows.push(twoColRow('Chromosome:', chromosome));
    rows.push(twoColRow('Species:', taxon));

    if (!isRef){
        rows.push(twoColRow('Syntenic Contig:', contigSourceId));
        rows.push(twoColRow('Ref location:', refStart + "&nbsp;-&nbsp;" + refEnd + " (" + refLength + "&nbsp;bp)" ));
        rows.push(twoColRow('Syn location:', synStart + "&nbsp;-&nbsp;" + synEnd + " (" + synLength + "&nbsp;bp)"));
        rows.push(twoColRow('Reversed:', strand));
        rows.push(twoColRow('Total Syn Contig Length:', contigLength));
        rows.push(twoColRow('Total Ref Contig Length:', refContigLength));
    } else {
        rows.push(twoColRow('Contig:', contigSourceId));
        rows.push(twoColRow('Location:', refStart + "&nbsp;-&nbsp;" + refEnd + " (" + refLength + "&nbsp;bp)"));
        rows.push(twoColRow('Total Contig Length:', refContigLength));
    }
    return table(rows);
}

function gffTssChabbert(track, feature) {
    var rows = new Array();

    var assignedFeat = feature.get("assignedfeat");
    var assignedFeature = feature.get("assignedfeature");

    if(assignedFeat == "NewTranscript" || assignedFeature == "NewTranscript") {
        rows.push(twoColRow('Assigned Feature:', "New Transcript"));
    }
    else {
        var gene = assignedFeature ? assignedFeature : assignedFeat;

        var link = "<a target='_blank' href='/a/app/record/gene/" + gene + "'>" + gene + "</a>";
        rows.push(twoColRow('Assigned Feature:', link));
    }
    return table(rows);
}

function sequenceTitle(track, feature) {
    var rows = new Array();

    var sourceId = feature.get("name");

    rows.push(twoColRow('ID:', sourceId));
    rows.push(twoColRow("Position:" , positionNoStrandString(track.refSeq.name, feature.get("startm"), feature.get("end"))));
    return table(rows);
}
