package org.apidb.apicommon.model.datasetInjector.custom.HostDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class RNASeqME49PostInfection extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Gregory::TgME49RnaSeqHuman"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTgME49HumanFoldChange"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTgME49HumanPercentile"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

