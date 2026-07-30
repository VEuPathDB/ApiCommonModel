package org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB;

import org.apidb.apicommon.model.datasetInjector.MicroarrayTwoChannelReferenceDesign;

public class MicroarrayDeRisiTimeSeries extends MicroarrayTwoChannelReferenceDesign {

    @Override
    public void injectTemplates() {
      super.injectTemplates();

      // we are setting hasPercentile to false so must inject these
      setPropValue("graphTextAttrName", "pctGraphAttr" + getDatasetName() + "_pct_graph");
      injectTemplate("expressionGraphAttributesPercentile");
      injectTemplate("graphTextAttributeCategory");

      // These two questions are curated rather than generic — they use the PFTimeSeries
      // vocabulary queries and an extra comparison-samples param — so hasMultipleSamples /
      // hasPercentileData / hasPageData stay false and the questions come from
      // microarrayDeRisiTimeSeries.dst instead of the generic expression templates.
      //
      // They used to be hardcoded in geneQuestions.xml, which meant they existed even on an
      // instance where this dataset is not loaded, referencing expr/pct graph attributes that
      // only exist when this presenter runs. Injecting them makes question and attribute
      // appear and disappear together, so the model stays dataset driven.
      injectTemplate("microarrayDeRisiTimeSeriesFoldChangeQuestion");
      injectTemplate("microarrayDeRisiTimeSeriesPercentileQuestion");
    }

  @Override
  public void addModelReferences() {
      super.addModelReferences();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByProfileSimilarity"); 

      // derived from the dataset rather than spelled out, so these track the injected
      // question names above instead of drifting from them
      String questionName = "GeneQuestions.GenesByMicroarray" + getDatasetName();
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", questionName);
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", questionName + "Percentile");

  }


}
