package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphsAndCoverage;

public class RNASeqClaytonHalflife extends CusomGenePageExpressionGraphsAndCoverage {


  @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "ClaytonDegradation::HalfLife");
  }
}
