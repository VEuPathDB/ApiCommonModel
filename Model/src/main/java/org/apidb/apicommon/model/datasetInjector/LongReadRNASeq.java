package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

import java.util.Map;

public class LongReadRNASeq extends DatasetInjector {


   protected String getInternalGeneQuestionName() {
        return "GeneQuestions.GenesByLongReadEvidence_" + getDatasetName();
    }

  protected String getInternalSpanQuestionName() {
	return "SpanQuestions.GenomicSpanByLongReadEvidence_" + getDatasetName();
  }

  @Override
  public void injectTemplates() {
    // TODO:  possibly inject jbrowse track??
    String projectName = getPropValue("projectName");
    String organismAbbrev = getPropValue("organismAbbrev");
    //String datasetName = getPropValue("datasetName");
      String datasetNamePattern = getPropValue("datasetNamePattern");
      String javaDatasetNamePattern = "";
      String datasetDisplayName = getPropValue("datasetDisplayName");
      String datasetPresenterId = getPropValue("presenterId");

      if (datasetNamePattern != null){
        javaDatasetNamePattern = datasetNamePattern.replace("%", ".*");
      }
      else{
        javaDatasetNamePattern = getPropValue("datasetName");
      }
      Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();

      setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
      setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));

      for (String key : globalProps.keySet()){
        //iterate over keys
        if (key.contains(javaDatasetNamePattern)){
                if (!key.contains(projectName)){
                        Map<String, String> datasetProps = globalProps.get(key);
                        String[] parts = key.split("_");
                        String extractOrgAbbrev = "";
                        extractOrgAbbrev = parts[0];
                        setPropValue("organismAbbrev", extractOrgAbbrev );
                        System.out.println(extractOrgAbbrev);
                        setPropValue("datasetName", key);
			setPropValue("datasetDisplayName", datasetDisplayName);
			setPropValue("datasetPresenterId", datasetPresenterId);
                        injectTemplate("jbrowseLongReadRNASeqSampleBuildProps");
                        }
                }
        }


    setPropValue("includeProjects", projectName);
    injectTemplate("LongReadGeneModelQuestion");
    injectTemplate("LongReadGeneModelSpanQuestion");

    setPropValue("questionName", getInternalGeneQuestionName());
    setPropValue("searchCategory", "searchCategory-longread");
    injectTemplate("internalGeneSearchCategory");

    setPropValue("questionName", getInternalSpanQuestionName());
    setPropValue("searchCategory", "searchCategory-longreadspan");
    injectTemplate("internalSpanSearchCategory");
  }

  @Override
  public void addModelReferences() {
	  addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", getInternalGeneQuestionName());
	  addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", getInternalSpanQuestionName());
	  //addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.IntronJunctionDynamicSearch");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

  
}
