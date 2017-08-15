package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqClaytonHalflife extends CusomGenePageExpressionGraphs {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "TODO");
  }



}
