package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();
      setOrganismAbbrevInternalFromDatasetName();

      injectTemplate("chipSeqCoverageTrack");
  }

  public void addModelReferences() { }


    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {};

        return declaration;
      }

}
