package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class LongReadRNASeq extends DatasetInjector {

  @Override
  public void injectTemplates() {
    // TODO:  possibly inject jbrowse track??
  }

  @Override
  public void addModelReferences() {
	  addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.LongReadTranscripCounts");
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
