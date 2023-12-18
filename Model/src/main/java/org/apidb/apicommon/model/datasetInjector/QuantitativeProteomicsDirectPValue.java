package org.apidb.apicommon.model.datasetInjector;


public class QuantitativeProteomicsDirectPValue extends QuantitativeProteomicsDirectComparison {


  @Override
  public void injectTemplates() {

    super.injectTemplates();

    injectTemplate("directComparisonGenericPValueQuestion");

    injectTemplate("directComparisonGenericPValueSamplesParamQuery");

    setPropValue("searchCategory", "searchCategory-proteomics-direct-conf-comparison");
    setPropValue("questionName", "GeneQuestions.GenesByProteomicsDirectPValue" + getDatasetName());
    injectTemplate("internalGeneSearchCategory");
  }



  @Override
  public void addModelReferences() {
    //super.addModelReferences();

    setDataType();
    String myDataType = getDataType();

    if(getPropValueAsBoolean("hasPageData")) {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
		      "GeneQuestions.GenesBy" + myDataType + "DirectWithConfidence" + getDatasetName());
    }


    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProteomicsDirectPValue" + getDatasetName() );

    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Proteomics::LogRatio"); 

    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ProteinExpressionGraphs");
  }
}
