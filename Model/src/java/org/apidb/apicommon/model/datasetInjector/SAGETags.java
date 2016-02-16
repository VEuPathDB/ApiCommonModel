package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class SAGETags extends DatasetInjector {

  @Override
  public void injectTemplates() {
  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesBySageTag");
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesBySageTagRStat");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "SageTags");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "question", "SageTagQuestions.SageTagByRStat");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "question", "SageTagQuestions.SageTagByLocation");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "question", "SageTagQuestions.SageTagBySequence");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "question", "SageTagQuestions.SageTagByGeneSourceId");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "question", "SageTagQuestions.SageTagByExpressionLevel");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "question", "SageTagQuestions.SageTagByRadSourceId");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "attribute", "overview");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "table", "AllCounts");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "table", "Genes");
      addWdkReference("SageTagRecordClasses.SageTagRecordClass", "table", "Locations");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
