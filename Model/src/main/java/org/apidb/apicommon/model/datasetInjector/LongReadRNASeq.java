package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class LongReadRNASeq extends DatasetInjector {


   protected String getInternalQuestionName() {
        return "GeneQuestions.GenesByLongReadEvidence_" + getDatasetName();
    }

  @Override
  public void injectTemplates() {
    // TODO:  possibly inject jbrowse track??
    String projectName = getPropValue("projectName");
    setPropValue("includeProjects", projectName);
    injectTemplate("LongReadGeneModelQuestion");


    setPropValue("questionName", getInternalQuestionName());
    setPropValue("searchCategory", "searchCategory-longread");
    injectTemplate("internalGeneSearchCategory");
  }

  @Override
  public void addModelReferences() {
	 // addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.LongReadTranscriptCounts");
	  addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", getInternalQuestionName());
	  addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.LongReadNovelGeneSpansBySourceId");
	  //addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.IntronJunctionDynamicSearch");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

  
}
