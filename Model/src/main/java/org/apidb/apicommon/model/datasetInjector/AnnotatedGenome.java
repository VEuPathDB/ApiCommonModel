package org.apidb.apicommon.model.datasetInjector;

import java.util.LinkedHashMap;
import java.util.Map;

import org.gusdb.wdk.model.WdkRuntimeException;

public class AnnotatedGenome extends UnannotatedGenome {

    protected boolean hasFilters = true;

    @Override
    public void injectTemplates() {
                super.injectTemplates();


      injectTemplate("jbrowseAnnotatedGenome");
      injectTemplate("jbrowseAnnotatedGeneDensity");
      injectTemplate("jbrowseCommonAa");

      // TODO: determine if any of the code in this method below this point is
      //   needed.  It is all related to old organism filter fields; need to see
      //   if it is used by any other code or can just be deleted.

    // dataset presenters/dataset classes xml files do not have PHYLUM information
    // hack until we have filters reading from datatabase (instead of relying on dataset xml files)
    // key value pairs obtained by running SQLs below in a EUPA database (e.g.: eupa-inc)

    //copy/paste from this SQL, run in eupa-inc:
    //
    //select 'kingdom.put("' || term || '","Fungi");'
    //from (select distinct term from (
    //select parentterm,term
    //from apidbtuning.organismtree
    //where parentterm = 'Fungi')
    //order by term)

    Map<String,String> kingdom = new LinkedHashMap<String, String>();
    {
      kingdom.put("Agaricomycetes","Fungi");
      kingdom.put("Blastocladiomycetes","Fungi");
      kingdom.put("Chytridiomycetes","Fungi");
      kingdom.put("Dothideomycetes","Fungi");
      kingdom.put("Eurotiomycetes","Fungi");
      kingdom.put("Glomeromycetes","Fungi");
      kingdom.put("Leotiomycetes","Fungi");
      kingdom.put("Microsporidia","Fungi");
      //  kingdom.put("Oomycetes","Fungi");
      kingdom.put("Pneumocystidomycetes","Fungi");
      kingdom.put("Pucciniomycetes","Fungi");
      kingdom.put("Saccharomycetes","Fungi");
      kingdom.put("Schizosaccharomycetes","Fungi");
      kingdom.put("Sordariomycetes","Fungi");
      kingdom.put("Tremellomycetes","Fungi");
      kingdom.put("Ustilaginomycetes","Fungi");
      kingdom.put("Zygomycetes","Fungi");
    }

    //copy/paste from this SQL, run in eupa-inc:
    //    
    //    select 'phylum.put("' || term || '","' || parentterm || '");'
    //    from ApidbTuning.OrganismTree
    //    where term in (
    //      select distinct substr(organism,1,instr(organism,' ') - 1)
    //      from ApidbTuning.OrganismTree)
    //    group by term,parentterm
    //    order by term,parentterm

    Map<String,String> phylum = new LinkedHashMap<String, String>();
    {
      phylum.put("Acanthamoeba","Amoebozoa");
      phylum.put("Albugo","Oomycetes");
      phylum.put("Allomyces","Blastocladiomycetes");
      phylum.put("Amphiamblys","Microsporidia");
      phylum.put("Anncaliia","Microsporidia");
      phylum.put("Aphanomyces","Oomycetes");
      phylum.put("Aspergillus","Eurotiomycetes");
      phylum.put("Babesia","Apicomplexa");
      phylum.put("Batrachochytrium","Chytridiomycetes");
      phylum.put("Blechomonas","Kinetoplastida");
      phylum.put("Bodo","Kinetoplastida");
      phylum.put("Botrytis","Leotiomycetes");
      phylum.put("Candida","Saccharomycetes");
      phylum.put("Cenococcum","Dothideomycetes");
      phylum.put("Chromera","Chromerida");
      phylum.put("Clavispora","Saccharomycetes");
      phylum.put("Cladophialophora","Eurotiomycetes");
      phylum.put("Coccidioides","Eurotiomycetes");
      phylum.put("Coprinopsis","Agaricomycetes");
      phylum.put("Crithidia","Kinetoplastida");
      phylum.put("Cryptococcus","Tremellomycetes");
      phylum.put("Cryptosporidium","Apicomplexa");
      phylum.put("Cyclospora","Apicomplexa");
      phylum.put("Cyphellophora","Eurotiomycetes");
      phylum.put("Cystoisospora","Apicomplexa");
      phylum.put("Cytauxzoon","Apicomplexa");
      phylum.put("Edhazardia","Microsporidia");
      phylum.put("Eimeria","Apicomplexa");
      phylum.put("Encephalitozoon","Microsporidia");
      phylum.put("Endotrypanum","Kinetoplastida");
      phylum.put("Entamoeba","Amoebozoa");
      phylum.put("Enterocytozoon","Microsporidia");
      phylum.put("Enterospora","Microsporidia");
      phylum.put("Exophiala","Eurotiomycetes");
      phylum.put("Fonsecaea","Eurotiomycetes");
      phylum.put("Fusarium","Sordariomycetes");
      phylum.put("Giardia","Diplomonadida");
      phylum.put("Gregarina","Apicomplexa");
      phylum.put("Hamiltosporidium","Microsporidia");
      phylum.put("Hammondia","Apicomplexa");
      phylum.put("Hepatospora","Microsporidia");
      phylum.put("Histoplasma","Eurotiomycetes");
      phylum.put("Homo","Chordata");
      phylum.put("Hyaloperonospora","Oomycetes");
      phylum.put("Kwoniella","Tremellomycetes");
      phylum.put("Leishmania","Kinetoplastida");
      phylum.put("Leptomonas","Kinetoplastida");
      phylum.put("Lomentospora","Sordariomycetes");
      phylum.put("Macaca","Chordata");
      phylum.put("Magnaporthe","Sordariomycetes");
      phylum.put("Malassezia","Ustilaginomycetes");
      phylum.put("Melampsora","Pucciniomycetes");
      phylum.put("Mitosporidium","Microsporidia");
      phylum.put("Monocercomonoides","Diplomonadida");
      phylum.put("Mucor","Zygomycetes");
      phylum.put("Mus","Chordata");
      phylum.put("Bos","Chordata");
      phylum.put("Naegleria","Amoebozoa");
      phylum.put("Nematocida","Microsporidia");
      phylum.put("Neospora","Apicomplexa");
      phylum.put("Neurospora","Sordariomycetes");
      phylum.put("Nosema","Microsporidia");
      phylum.put("Ordospora","Microsporidia");
      phylum.put("Paracoccidioides","Eurotiomycetes");
      phylum.put("Paratrypanosoma","Kinetoplastida");
      phylum.put("Penicillium","Eurotiomycetes");
      phylum.put("Phanerochaete","Agaricomycetes");
      phylum.put("Phycomyces","Zygomycetes");
      phylum.put("Phytophthora","Oomycetes");
      phylum.put("Plasmodium","Apicomplexa");
      phylum.put("Pneumocystis","Pneumocystidomycetes");
      phylum.put("Pseudoloma","Microsporidia");
      phylum.put("Puccinia","Pucciniomycetes");
      phylum.put("Pythium","Oomycetes");
      phylum.put("Rhizopus","Zygomycetes");
      phylum.put("Rhizophagus","Glomeromycetes");
      phylum.put("Saccharomyces","Saccharomycetes");
      phylum.put("Saprolegnia","Oomycetes");
      phylum.put("Sarcocystis","Apicomplexa");
      phylum.put("Scedosporium","Sordariomycetes");
      phylum.put("Schizosaccharomyces","Schizosaccharomycetes");
      phylum.put("Sclerotinia","Leotiomycetes");
      phylum.put("Sordaria","Sordariomycetes");
      phylum.put("Spironucleus","Diplomonadida");
      phylum.put("Spizellomyces","Chytridiomycetes");
      phylum.put("Sporisorium","Ustilaginomycetes");
      phylum.put("Sporothrix","Sordariomycetes");
      phylum.put("Spraguea","Microsporidia");
      phylum.put("Talaromyces","Eurotiomycetes");
      phylum.put("Theileria","Apicomplexa");
      phylum.put("Toxoplasma","Apicomplexa");
      phylum.put("Trachipleistophora","Microsporidia");
      phylum.put("Tremella","Tremellomycetes");
      phylum.put("Trichoderma","Sordariomycetes");
      phylum.put("Trichomonas","Trichomonadida");
      phylum.put("Trypanosoma","Kinetoplastida");
      phylum.put("Uncinocarpus","Eurotiomycetes");
      phylum.put("Ustilago","Ustilaginomycetes");
      phylum.put("Vavraia","Microsporidia");
      phylum.put("Vitrella","Chromerida");
      phylum.put("Vittaforma","Microsporidia");
      phylum.put("Yarrowia","Saccharomycetes");
      phylum.put("Zymoseptoria","Dothideomycetes");
    }

    // getting properties defined in .prop file
    String projectName = getPropValue("projectName");
    String organismAbbrev = getPropValue("organismAbbrev");

    Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();
    String orgPropsKey = projectName + ":" + organismAbbrev + "_RSRC";
    Map<String, String> orgProps = globalProps.get(orgPropsKey);

    if (orgProps == null) throw new WdkRuntimeException("No global property set for " + orgPropsKey);
    String organismFullName = orgProps.get("organismFullName");

    String runExportPred = orgProps.get("runExportPred");
    if(runExportPred != null && runExportPred.toLowerCase().equals("true")) {
        injectTemplate("jbrowseExportPredPbrowse");
    }
    
    String[] orgs = organismFullName.split(" ");

    String speciesWithSpaces, familySpecies;//, species;
    // Strings "species" and "familySpecies" should be called: "genusSpeciesDisplayName" and "orgFilterName" respectively
    //    "species" MAY contain spaces (eg: "sp. 1")
    //    "familySpecies" CANNOT contain spaces so we replace space by = (eg: "sp.=1")
    //
    // The templates below will generate filter names in the model based on these Strings.
    //   These will be used by WDK (AnswerFilterLayout.java) 
    //   to prepare maps with organism counts per Phylum, Genus and Species
    //   which will be used by the jsp to generate the table with correct headers/colspans

    // None of the names used in a full species name (eg: Apicomplexa Plasmodium falciparum) 
    //   should contain spaces or any of the folowing characters: 
    //     dash - 
    //     underscore _ 
    //     equal sign = 

    // if optionalSpecies -coming from presenters- contains a value, it is a species value that includes spaces or any of the above chars; otherwise empty
    if( getPropValue("optionalSpecies") != null && !getPropValue("optionalSpecies").isEmpty() ) {
      speciesWithSpaces = getPropValue("optionalSpecies");
      //species = orgs[0] + " " + speciesWithSpaces;
      speciesWithSpaces = speciesWithSpaces.replaceAll("-", "=-");
      speciesWithSpaces = speciesWithSpaces.replaceAll("_", "=_");
      familySpecies = orgs[0] + "-" + speciesWithSpaces.replaceAll(" ", "=");
    } else {
      //species = orgs[0] + " " + orgs[1];  // for popup on distinct filter
      orgs[1] = orgs[1].replaceAll("-", "==");
      orgs[1] = orgs[1].replaceAll("_", "===");
      familySpecies = orgs[0] + "-" + orgs[1];  // for filter name
    }

    // adding phylum to familySpecies, for genera included in the Map above (eg: Plasmodium)
    if (phylum.containsKey(orgs[0])) 
      familySpecies = phylum.get(orgs[0]) + "-" + familySpecies;
    // adding kingdom to familySpecies, for phila included in either Map above (eg: Agaricomycetes,Plasmodium)
    if (kingdom.containsKey(phylum.get(orgs[0]))) 
      familySpecies = "Fungi-" + familySpecies;
    //else if (phylum.containsKey(orgs[0])) 
    //  familySpecies = "nonFungi-" + familySpecies;

    // setting properties to be used in template
    setPropValue("familySpecies", familySpecies);
    setPropValue("organismFullName", organismFullName);


    if(getPropValueAsBoolean("isEuPathDBSite")) {
        setPropValue("includeProjects", projectName + ",EuPathDB,UniDB");
    } else {
        setPropValue("includeProjects", projectName + ",UniDB");
    }

    setPropValue("includeProjectsExcludeEuPathDB", projectName + ",UniDB");

    // old organism filters, unused
    //  injectTemplate("geneFilter");
    //  injectTemplate("geneFilterLayout");
    // Only if reference strain - set distinct gene instance
    //  if (hasFilters && orgProps.get("isReferenceStrain").equals("true")) {
    //  setPropValue("species", species);
    //  injectTemplate("distinctGeneFilterLayout");
    //  injectTemplate("distinctGeneFilter"); 
    // }

  }

  @Override
  public void addModelReferences() {
    super.addModelReferences();

    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByLocation");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesBySimilarity");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GeneByLocusTag");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTaxon");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByGeneModelChars");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByExonCount");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesWithUserComments");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesWithSignalPeptide");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTransmembraneDomains");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "overview");

    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Notes");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Alias");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ProteinProperties");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Sequences");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "GeneTranscripts");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "AlternateProducts");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "UserComments");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "PreferredProducts");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ProteinDatabase");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "GeneLocation");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "PubMed");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ECNumbers");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "GOTerms");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "GOSlim");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "GeneLinkouts");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Seqedits");

    addWdkReference("EstRecordClasses.EstRecordClass", "table", "Reference");
    addWdkReference("EstRecordClasses.EstRecordClass", "table", "AlignmentInfo");

    // if showReferenceTranscriptomics is true, add wdkReference to enable transcritomics of reference strain to be visible for this genome's gene pages.
    if(getPropValueAsBoolean("showReferenceTranscriptomics")){
  addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ExpressionGraphs");
    }

    // getting properties defined in .prop file
    String projectName = getPropValue("projectName");

    // no Popsets for VectorBase
    if (!(projectName.equals("VectorBase") ||
	  projectName.equals("HostDB"))){
	addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetsBySimilarity");
    }

    // no genes TrichDB organism
    if (!(projectName.equals("TrichDB"))){
	addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "SyntenyGbrowseUrl");
    }



    // no Apollo updates for CryptoDB, HostDB, GiardiaDB, MicrosporidiaDB and TrichDB
    if (!(projectName.equals("CryptoDB")) ||
	(projectName.equals("HostDB")) ||
	(projectName.equals("MicrosporidiaDB")) ||
	(projectName.equals("TrichDB"))){
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ApolloProducts");
    }
  }

  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String [][] propertiesDeclaration = { {"isEuPathDBSite", "if true, genome will be available on EuPathdB"},
                                          {"optionalSpecies", "if species name contains two words, e.g. sp. 1"},
                                          {"specialLinkDisplayText", "gene-page text for genome annotation status"},
                                          {"specialLinkExternalDbName", "external DB name for annotation link"},
                                          {"isCurated", "values true|false for whether genome is under active curation"},
                                          {"updatedAnnotationText", "text to use when making link to updated record"},
                                          {"showReferenceTranscriptomics", "if true, show transcriptomics data of reference strain on gene page"},
    };

    return propertiesDeclaration;
  } 
}
