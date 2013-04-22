package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class MicroarrayWatersHP extends CusomGenePageExpressionGraphs {

  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Waters::Ver2");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.BergheiGenesByExpressionPercentile");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.BergheiGenesByExpressionFoldChange");
  }

}
