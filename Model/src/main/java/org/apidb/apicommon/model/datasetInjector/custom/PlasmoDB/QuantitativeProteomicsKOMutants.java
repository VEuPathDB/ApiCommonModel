package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsDirectComparison;

public class QuantitativeProteomicsKOMutants extends QuantitativeProteomicsDirectComparison {

  @Override
  public void injectTemplates() {
      super.injectTemplates();
  }

  @Override
  public void addModelReferences() {

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirectPValuepberANKA_quantitativeMassSpec_Modrzynska_KO_Mutants_RSRC"); 


      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Proteomics::LogRatio"); 
  }
}
