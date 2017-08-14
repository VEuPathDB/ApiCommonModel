package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.MicroarrayTwoChannelReferenceDesign;

public class MicroarrayDeRisiTimeSeries extends MicroarrayTwoChannelReferenceDesign {

    @Override
    public void injectTemplates() {
      super.injectTemplates();

      // Questions are hard coded in the model w/ the same name that would have been injected

      // we are setting hasPercentile to false so must inject these 
      setPropValue("graphTextAttrName", "pctGraphAttr" + getDatasetName() + "_pct_graph");
      injectTemplate("expressionGraphAttributesPercentile");
      injectTemplate("graphTextAttributeCategory");

    }

  @Override
  public void addModelReferences() {
      super.addModelReferences();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProfileSimilarity"); 

      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMicroarraypfal3D7_microarrayExpression_Derisi_HB3_TimeSeries_RSRC"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMicroarraypfal3D7_microarrayExpression_Derisi_HB3_TimeSeries_RSRCPercentile"); 

  }


}
