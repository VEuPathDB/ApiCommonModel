package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.MicroarrayOneChannelRma;

public class MicroarrayBirkholtzGametocyte extends MicroarrayOneChannelRma {


  @Override
  public void addModelReferences() {
      super.addModelReferences();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByGametocyteProfileSimilarity"); 
  }



}
