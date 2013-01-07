package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RNASeqSnyderCompAnn extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "CandidaAlbicansSC5314::RnaSeqCompAnn"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqFoldChangeCalbCompAnn"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRnaSeqPercentileCalbCompAnn"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

