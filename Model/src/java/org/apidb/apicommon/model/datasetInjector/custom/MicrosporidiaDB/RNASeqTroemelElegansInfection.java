package org.apidb.apicommon.model.datasetInjector.custom.MicrosporidiaDB;

import org.apidb.apicommon.model.datasetInjector.RNASeq;

public class RNASeqTroemelElegansInfection extends RNASeq {


  @Override
  public void addModelReferences() {
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Troemel::CelegansInfectionTimeSeries");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionFC");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionPercentile");
  }
}
