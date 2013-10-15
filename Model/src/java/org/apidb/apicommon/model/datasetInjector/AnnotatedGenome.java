package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import java.util.Map;

public class AnnotatedGenome extends DatasetInjector {

  @Override
  public void injectTemplates() {

    String projectName = getPropValue("projectName");
    String organismAbbrev = getPropValue("organismAbbrev");

    try {

      Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();
      Map<String, String> orgProps = globalProps.get(projectName + ":" + organismAbbrev + "_RSRC");

      String organismFullName = orgProps.get("organismFullName");

      setPropValue("organismAbbrev", organismAbbrev);
      setPropValue("organismFullName", organismFullName);

      if(getPropValueAsBoolean("isEuPathDBSite")) {
        setPropValue("includeProjects", projectName + ",EuPathDB");
      } else {
        setPropValue("includeProjects", projectName);
      }   

      injectTemplate("geneFilter");
      injectTemplate("geneFilterLayout");

      // reference strain - set distinct gene instance
      if(orgProps.get("isReferenceStrain").equals("true")) {

        String orthomclAbbrev = orgProps.get("orthomclAbbrev");
        organismAbbrev = orthomclAbbrev + "_distinct_gene";

        String[] orgs = organismFullName.split(" ");
        String species = orgs[0] + " " + orgs[1];

        setPropValue("organismAbbrev", organismAbbrev);
        setPropValue("orthomclAbbrev", orthomclAbbrev);
        setPropValue("species", species);

        injectTemplate("geneFilterLayout");
        injectTemplate("distinctGeneFilter"); 
      } 
    }
    catch(NullPointerException e) {
      System.err.println("Caught NullPointerException: " + e.getMessage()); 
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

    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "attribute", "overview");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequenceBySourceId");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByTaxon");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesBySimilarity");

    addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolatesBySimilarity");

    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "attribute", "overview");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansBySourceId");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansByMotifSearch");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
