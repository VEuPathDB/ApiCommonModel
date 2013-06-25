package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class NonCodingRNASeq extends DatasetInjector {

  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();
      setOrganismAbbrevInternalFromDatasetName();

      injectTemplate("ncRNASeqCoverageTrack");
  }

  public void addModelReferences() { }


    public String[][] getPropertiesDeclaration() {
        String [][] declaration = {};

        return declaration;
      }

}
