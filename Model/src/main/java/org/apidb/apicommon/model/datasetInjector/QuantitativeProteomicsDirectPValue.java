package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsDirectPValue extends QuantitativeProteomicsDirectComparison {


  @Override
  public void injectTemplates() {

    super.injectTemplates();

    injectTemplate("directComparisonGenericPValueQuestion");

    injectTemplate("directComparisonGenericPValueSamplesParamQuery");
  }



  @Override
  public void addModelReferences() {

    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirectPValue" + getDatasetName() );

    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Proteomics::LogRatio"); 

  }
}
