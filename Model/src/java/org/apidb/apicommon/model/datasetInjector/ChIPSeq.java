package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();

      if(getPropValueAsBoolean("logScaleOnly")) {
        injectTemplate("chipSeqCoverageTrack");
      } else {
        injectTemplate("chipSeqCoverageTrack");
        injectTemplate("chipSeqCoverageTrackUnlogged");
      }
  }

  @Override
  public void addModelReferences() { }


  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = { 
                      {"logScaleOnly", "true only show log scale, otherwise show both"}, 
                                };
      return declaration;
  }

}
