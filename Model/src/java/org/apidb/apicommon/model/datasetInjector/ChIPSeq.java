package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  public void injectTemplates() {
      String datasetName = getDatasetName();

      String[] datasetWords = datasetName.split("_");
      setPropValue("organismAbbrev", datasetWords[0]);

      injectTemplate("chipSeqCoverageTrack");
  }

  public void addModelReferences() { }


    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {};

        return declaration;
      }

}
