package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsDirectComparison;

public class QuantitativeProteomicsPfalRegulatedProteome extends QuantitativeProteomicsDirectComparison {

  @Override
  public void injectTemplates() {
      super.injectTemplates();
  }

  @Override
  public void addModelReferences() {

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirectPValuepfal3D7_quantitativeMassSpec_Ganter_Regulated_Proteome_RSRC");

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Proteomics::LogRatio"); 
  }
}
