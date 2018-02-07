package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsDirectComparison;

public class QuantProteomicsHillSurfaceProteomics extends QuantitativeProteomicsDirectComparison {

  @Override
  public void injectTemplates() {
      super.injectTemplates();
  }

  @Override
  public void addModelReferences() {
      //  add all references from ProteinExpressionMassSpec first
      super.addModelReferences();

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirectConfidencetbruTREU927_quantitativeMassSpec_BSF_PCF_Surface_Proteomics_RSRC"); 


      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirecttbruTREU927_quantitativeMassSpec_BSF_PCF_Surface_Proteomics_RSRC"); 

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Proteomics::LogRatio"); 

	

  }


}
