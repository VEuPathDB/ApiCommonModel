package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.RNASeq;
public class RNASeqMetaCycle_Rijo_Circadian_Regulation extends RNASeq {


  @Override
  public void addModelReferences() {

      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqMetaCycletbruTREU927_Rijo_Circadian_Regulation_rnaSeq_RSRC"); 
  }



}
