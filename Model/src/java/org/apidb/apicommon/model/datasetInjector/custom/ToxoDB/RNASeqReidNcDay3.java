package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqReidNcDay3 extends CusomGenePageExpressionGraphsAndCoverage {

  @Override
  public void addModelReferences() {
 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByNcLivRNASeqExpressionPercentile"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Reid::NcRnaSeq" );
  }
}
