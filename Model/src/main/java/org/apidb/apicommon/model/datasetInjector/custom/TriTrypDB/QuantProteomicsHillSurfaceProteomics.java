package org.apidb.apicommon.model.datasetInjector.custom.TriTrypDB;

import org.apidb.apicommon.model.datasetInjector.QuantitativeProteomicsDirectComparison;

public class QuantProteomicsHillSurfaceProteomics extends QuantitativeProteomicsDirectComparison {

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirectConfidencetbruTREU927_quantitativeMassSpec_BSF_PCF_Surface_Proteomics_RSRC"); 
  }


}
