package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.RNASeq;

public class RNASeqMetaCycle_ncraOR74A_Bharath extends RNASeq {

  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqMetaCyclencraOR74A_Bharath_Circadian_Time_Course_ebi_rnaSeq_RSRC"); 
  }

}
