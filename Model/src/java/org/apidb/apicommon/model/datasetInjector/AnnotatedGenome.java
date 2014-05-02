package org.apidb.apicommon.model.datasetInjector;

import java.util.Map;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import org.gusdb.wdk.model.WdkRuntimeException;

public class AnnotatedGenome extends DatasetInjector {

  @Override
		public void injectTemplates() {

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
    // String species is used in distinct filter: displayName, description and SQL parameter value; 
    //      it MAY contain spaces (eg: "sp. 1")
    // String familySpecies is used in the filter's name: both distinct filters and instance filters; 
    //      it CANNOT contain spaces (eg: "sp.=1")
    // This convention will allow the layout (WDK/.../AnswerFilterLayout.java) 
    //      to extract the organism filter table headers (family, species and strain) to prepare maps that will be used by the jsp

    if( getPropValue("optionalSpecies") != null && !getPropValue("optionalSpecies").isEmpty() ) {
			speciesWithSpaces = getPropValue("optionalSpecies");
			species = orgs[0] + " " + speciesWithSpaces;
			familySpecies = orgs[0] + "-" + speciesWithSpaces.replaceAll(" ", "=");
    } else {
			species = orgs[0] + " " + orgs[1]; 
			familySpecies = orgs[0] + "-" + orgs[1]; 
    }

    // setting properties to be used in template
    setPropValue("familySpecies", familySpecies);
    setPropValue("organismFullName", organismFullName);
    if(getPropValueAsBoolean("isEuPathDBSite")) {
      setPropValue("includeProjects", projectName + ",EuPathDB");
    } else {
      setPropValue("includeProjects", projectName);
    }   
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
