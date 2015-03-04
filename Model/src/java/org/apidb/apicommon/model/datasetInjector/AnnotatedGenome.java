package org.apidb.apicommon.model.datasetInjector;

import java.util.Map;
import java.util.LinkedHashMap;
import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import org.gusdb.wdk.model.WdkRuntimeException;

public class AnnotatedGenome extends DatasetInjector {
	
  @Override
		public void injectTemplates() {

		// dataset presenters/dataset classes xml files do not have PHYLUM information
		// hack until we have filters reading from datatabase (instead of relying on dataset xml files)
		// key value pairs obtained from database:
		//     select term,parentterm
		//     from ApidbTuning.OrganismTree
		//     where term in (
		//      select distinct substr(organism,1,instr(organism,' ') - 1)
		//      from ApidbTuning.OrganismTree)
		//     group by term,parentterm
		//     order by term,parentterm

		  Map<String,String> phylum = new LinkedHashMap<String, String>();
			{
				// fungi
				phylum.put("Ajellomyces","Eurotiomycetes");
				phylum.put("Albugo","Oomycetes");
				phylum.put("Allomyces","Blastocladiomycetes");
				phylum.put("Aphanomyces","Oomycetes");
				phylum.put("Aspergillus","Eurotiomycetes");
				phylum.put("Batrachochytrium","Chytridiomycetes");
				phylum.put("Botryotinia","Leotiomycetes");
				phylum.put("Candida","Saccharomycetes");
				phylum.put("Coccidioides","Eurotiomycetes");
				phylum.put("Coprinopsis","Agaricomycetes");
				phylum.put("Cryptococcus","Tremellomycetes");
				phylum.put("Fusarium","Sordariomycetes");
				phylum.put("Hyaloperonospora","Oomycetes");
				phylum.put("Magnaporthe","Sordariomycetes");
				phylum.put("Malassezia","Ustilaginomycetes");
				phylum.put("Melampsora","Pucciniomycetes");
				phylum.put("Mucor","Zygomycetes");
				phylum.put("Neosartorya","Eurotiomycetes");
				phylum.put("Neurospora","Sordariomycetes");
				phylum.put("Phanerochaete","Agaricomycetes");
				phylum.put("Phycomyces","Zygomycetes");
				phylum.put("Phytophthora","Oomycetes");
				phylum.put("Pneumocystis","Pneumocystidomycetes");
				phylum.put("Puccinia","Pucciniomycetes");
				phylum.put("Pythium","Oomycetes");
				phylum.put("Rhizopus","Zygomycetes");
				phylum.put("Saccharomyces","Saccharomycetes");
				phylum.put("Saprolegnia","Oomycetes");
				phylum.put("Schizosaccharomyces","Schizosaccharomycetes");
				phylum.put("Sclerotinia","Leotiomycetes");
				phylum.put("Sordaria","Sordariomycetes");
				phylum.put("Spizellomyces","Chytridiomycetes");
				phylum.put("Sporisorium","Ustilaginomycetes");
				phylum.put("Talaromyces","Eurotiomycetes");
				phylum.put("Tremella","Tremellomycetes");
				phylum.put("Trichoderma","Sordariomycetes");
				phylum.put("Ustilago","Ustilaginomycetes");
				phylum.put("Yarrowia","Saccharomycetes");
				// eupathdb
				phylum.put("Acanthamoeba","Amoebozoa");
				phylum.put("Anncaliia","Microsporidia");
				phylum.put("Babesia","Apicomplexa");
       	phylum.put("Chromera","Apicomplexa");
				phylum.put("Crithidia","Kinetoplastida");
				phylum.put("Cryptosporidium","Apicomplexa");
				phylum.put("Cytauxzoon","Apicomplexa"); //b24
				phylum.put("Edhazardia","Microsporidia");
				phylum.put("Eimeria","Apicomplexa");
				phylum.put("Encephalitozoon","Microsporidia");
				phylum.put("Endotrypanum","Kinetoplastida");
				phylum.put("Entamoeba","Amoebozoa");
				phylum.put("Enterocytozoon","Microsporidia");
				phylum.put("Giardia","Diplomonadida");
				phylum.put("Gregarina","Apicomplexa");
				phylum.put("Hamiltosporidium","Microsporidia");
				phylum.put("Hammondia","Apicomplexa");
				phylum.put("Leishmania","Kinetoplastida");
				phylum.put("Mitosporidium","Microsporidia"); //b24
				phylum.put("Naegleria","Amoebozoa");
				phylum.put("Nematocida","Microsporidia");
				phylum.put("Neospora","Apicomplexa");
				phylum.put("Nosema","Microsporidia");
				phylum.put("Ordospora","Microsporidia"); //b24
				phylum.put("Plasmodium","Apicomplexa");
				phylum.put("Sarcocystis","Apicomplexa");
				phylum.put("Spironucleus","Diplomonadida");
				phylum.put("Spraguea","Microsporidia");
				phylum.put("Theileria","Apicomplexa");
				phylum.put("Toxoplasma","Apicomplexa");
				phylum.put("Trachipleistophora","Microsporidia");
				phylum.put("Trichomonas","Trichomonadida");
				phylum.put("Trypanosoma","Kinetoplastida");
				phylum.put("Vavraia","Microsporidia");
      	phylum.put("Vitrella","Apicomplexa");
				phylum.put("Vittaforma","Microsporidia");

			}

			// getting properties defined in .prop file
    String projectName = getPropValue("projectName");
    String organismAbbrev = getPropValue("organismAbbrev");

    Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();
    String orgPropsKey = projectName + ":" + organismAbbrev + "_RSRC";
    Map<String, String> orgProps = globalProps.get(orgPropsKey);
    if (orgProps == null) throw new WdkRuntimeException("No global property set for " + orgPropsKey);
    String organismFullName = orgProps.get("organismFullName");
    
    String[] orgs = organismFullName.split(" ");

    String speciesWithSpaces, species, familySpecies;
		// Strings "species" and "familySpecies" should be called: "genusSpeciesDisplayName" and "genusSpeciesFilterName" respectively
    //    "species" MAY contain spaces (eg: "sp. 1")
    //    "familySpecies" CANNOT contain spaces (eg: "sp.=1")
    // The templates below will generate filter names in the model based on these Strings.
		//   These will be used by WDK (AnswerFilterLayout.java) 
    //   to prepare maps with organism counts per Phylum, Genus and Species
    //   which will be used by the jsp to generate the table with correct headers/colspans

		// if optionalSpecies -coming from presenters- contains a value, it is a species value that includes spaces; otherwise empty
    if( getPropValue("optionalSpecies") != null && !getPropValue("optionalSpecies").isEmpty() ) {
			speciesWithSpaces = getPropValue("optionalSpecies");
			species = orgs[0] + " " + speciesWithSpaces;
			familySpecies = orgs[0] + "-" + speciesWithSpaces.replaceAll(" ", "=");
    } else {
			species = orgs[0] + " " + orgs[1]; 
			familySpecies = orgs[0] + "-" + orgs[1]; 
    }

		// adding phylum to families (genus) included in the Map above
		if (phylum.containsKey(orgs[0])) familySpecies = phylum.get(orgs[0]) + "-" + familySpecies;

    // setting properties to be used in template
    setPropValue("familySpecies", familySpecies);
    setPropValue("organismFullName", organismFullName);
    if(getPropValueAsBoolean("isEuPathDBSite")) setPropValue("includeProjects", projectName + ",EuPathDB");
    else setPropValue("includeProjects", projectName);

		// inject templates
    injectTemplate("geneFilter");
    injectTemplate("geneFilterLayout");
    // Only if reference strain - set distinct gene instance
    if(orgProps.get("isReferenceStrain").equals("true")) {
      setPropValue("species", species);
      injectTemplate("distinctGeneFilterLayout");
      injectTemplate("distinctGeneFilter"); 
    }
  }

  @Override
		public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "InternalQuestions.GenesByOrthologs");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByLocation");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesBySimilarity");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GeneByLocusTag");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTaxon");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByGeneType");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByExonCount");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesWithUserComments");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesWithSignalPeptide");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTransmembraneDomains");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "overview");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Notes");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Alias");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ProteinDatabase");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "GeneLocation");

    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "attribute", "overview");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequenceBySourceId");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByTaxon");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesBySimilarity");

    addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesBySimilarity");

    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "attribute", "overview");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansBySourceId");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansByMotifSearch");
  }

  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  @Override
		public String[][] getPropertiesDeclaration() {
    String [][] propertiesDeclaration = { {"isEuPathDBSite", "if true, genome will be available on EuPathdB"},
                                          {"optionalSpecies", "if species name contains two words, e.g. sp. 1"},
		};

    return propertiesDeclaration;
  } 
}
