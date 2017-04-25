package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.MicroarrayOneChannelRma;

public class MicroarrayWhiteCellCycle extends MicroarrayOneChannelRma {


  @Override
  public void addModelReferences() {
      super.addModelReferences();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByToxoProfileSimilarity"); 
  }



}
