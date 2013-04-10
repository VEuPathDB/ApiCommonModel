package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ProteinExpressionMassSpec extends DatasetInjector {

  public void injectTemplates() {

      // inject Pbrowse
      // inject Gbrowse
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByMassSpec");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "OrfQuestions.OrfsByMassSpec");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecMod");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecDownload");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpec");
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
