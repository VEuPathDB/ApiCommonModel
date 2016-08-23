package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPChip extends DatasetInjector {

  @Override
  public void injectTemplates() {

    setPropValue ("organismAbbrevDisplay", getOrganismAbbrevDisplayFromDatasetName());
    String featureName = getPropValue("datasetDisplayName").replace(' ', '_');
    setPropValue ("featureName", featureName);

    String key = getPropValue("key");
    if (key.length() != 0) {
        setPropValue ("key", " - " + key);
    }
    injectTemplate("chipChipSmoothed");
    injectTemplate("chipChipPeaks");

    setPropValue("gbrowseTrackName", getDatasetName() + "_chipChipSmoothed");
    injectTemplate("gbrowseTrackCategory");

    setPropValue("gbrowseTrackName", getDatasetName() + "_chipChipPeaks");
    injectTemplate("gbrowseTrackCategory");

  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByChIPchip");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
