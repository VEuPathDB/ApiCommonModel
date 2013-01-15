package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayTroellCellCycle  extends DatasetInjector {

  public void injectTemplates() {
  }

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByPercentileTroellCC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesbyFoldChangeTroellCC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Troell::CellCycle"); 
  }

  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}

