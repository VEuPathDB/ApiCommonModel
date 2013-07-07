package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();
      setOrganismAbbrevInternalFromDatasetName();

      injectTemplate("chipSeqCoverageTrack");
  }

  @Override
  public void addModelReferences() { }


  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {};
      return declaration;
  }

}
