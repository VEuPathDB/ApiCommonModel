package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.AntibodyArray;

public class CromptonAbMicroarray extends AntibodyArray {



  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCromptonAbFoldChange");
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Crompton::AbMicroarray");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] exprDeclaration = super.getPropertiesDeclaration();
   
      String[][] declaration = {};
      
      return combinePropertiesDeclarations(exprDeclaration, declaration);
  }



}
