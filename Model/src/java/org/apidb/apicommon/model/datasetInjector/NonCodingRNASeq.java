package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class NonCodingRNASeq extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();

      injectTemplate("ncRNASeqCoverageTrack");

      setPropValue("gbrowseTrackName", getDatasetName() + "Coverage");
      injectTemplate("gbrowseTrackCategory");
  }

  @Override
  public void addModelReferences() { }


  @Override
  public String[][] getPropertiesDeclaration() {
    String [][] declaration = {};
    return declaration;
  }

}
