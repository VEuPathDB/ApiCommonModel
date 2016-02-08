package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();

      injectTemplate("chipSeqCoverageTrackUnlogged");
      setPropValue("gbrowseTrackName", getDatasetName() + "CoverageUnlogged");
      injectTemplate("gbrowseTrackCategory");

  }

  @Override
  public void addModelReferences() { }


    @Override
	public String[][] getPropertiesDeclaration() {
        String[][] propertiesDeclaration = {};
        return propertiesDeclaration;
    }

}
