package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayWatersHP extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Waters::Ver2");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.BergheiGenesByExpressionPercentile");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.BergheiGenesByExpressionFoldChange");
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
