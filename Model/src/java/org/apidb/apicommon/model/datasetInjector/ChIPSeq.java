package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  public void injectTemplates() {
      setPropValue("organismAbbrev", getOrganismAbbrevFromDatasetName());

      injectTemplate("chipSeqCoverageTrack");
  }

  public void addModelReferences() { }


    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {};

        return declaration;
      }

}
