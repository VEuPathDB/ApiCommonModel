package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.model.datasetInjector.RNASeq;

public class RNASeqMetaCycle_ncraOR74A_Hurley extends RNASeq {

  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqMetaCyclencraOR74A_Hurley_2014_NC_3_ebi_rnaSeq_RSRC"); 
  }

}
