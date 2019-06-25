package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.AntibodyArray;

public class NatInfectAntibodyArray extends AntibodyArray {

  @Override
  public void addModelReferences() {
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByNaturalInfection");
    //    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "ICEMR::AbMicroarray");

    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "HostResponseGraphs");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] exprDeclaration = super.getPropertiesDeclaration();
    String[][] propertiesDeclaration = {};
    return combinePropertiesDeclarations(exprDeclaration, propertiesDeclaration);
  }

}
