package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MicroarrayProbes extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();
      String datasetName = getDatasetName();

      setOrganismAbbrevFromDatasetName();
      String organismAbbrevDisplay = getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      injectTemplate("microarrayProbesGBrowseTrack");
      injectTemplate("gbrowseTrackCategory");

  }

  @Override
  public void addModelReferences() {
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {
      };
      return propertiesDeclaration;
  }

}
