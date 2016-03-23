package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.MicroarrayTwoChannelReferenceDesign;

public class MicroarrayDeRisiTimeSeries extends MicroarrayTwoChannelReferenceDesign {

  @Override
  public void addModelReferences() {
      super.addModelReferences();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProfileSimilarity"); 
  }


}
