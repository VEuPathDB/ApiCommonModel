package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class NcbiTaxonomy extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByTaxon"); 
      addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByTaxon"); 
      addWdkReference("IsolateRecordClasses.IsolateRecordClass", "question", "IsolateQuestions.IsolateByTaxon"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "attribute", "overview"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
