package org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsDirectComparison;

public class QuantitativeProteomicsAuranofin extends QuantitativeProteomicsDirectComparison {

  @Override
  public void injectTemplates() {
      super.injectTemplates();
  }

  @Override
  public void addModelReferences() {

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirectPValueehisHM1IMSS_quantitativeMassSpec_Shaulov_Auranofin_Adapted_RSRC");
  }
}
