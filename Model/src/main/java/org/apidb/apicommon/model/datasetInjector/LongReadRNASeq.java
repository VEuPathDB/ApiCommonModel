package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

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
