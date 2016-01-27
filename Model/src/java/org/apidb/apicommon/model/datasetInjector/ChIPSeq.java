package org.apidb.apicommon.model.datasetInjector;

import org.gusdb.wdk.model.WdkRuntimeException;
import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();

      String scale = getPropValue("scale");

      if(scale.toLowerCase().equals("log")) {
          injectTemplate("chipSeqCoverageTrack");
          setPropValue("gbrowseTrackName", getDatasetName() + "Coverage");
          injectTemplate("gbrowseTrackCategory");
      } 
      else if(scale.toLowerCase().equals("linear")) {
          injectTemplate("chipSeqCoverageTrackUnlogged");
          setPropValue("gbrowseTrackName", getDatasetName() + "CoverageUnlogged");
          injectTemplate("gbrowseTrackCategory");
      } 
      else if(scale.toLowerCase().equals("both")) {
          injectTemplate("chipSeqCoverageTrack");
          injectTemplate("chipSeqCoverageTrackUnlogged");

          setPropValue("gbrowseTrackName", getDatasetName() + "Coverage");
          injectTemplate("gbrowseTrackCategory");
          setPropValue("gbrowseTrackName", getDatasetName() + "CoverageUnlogged");
          injectTemplate("gbrowseTrackCategory");

      } 
      else {
          throw new WdkRuntimeException("property [scale] should be one of [log,linear,both]");
      }

  }

  @Override
  public void addModelReferences() { }


  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = { 
                      {"scale", "log, linear or both"}, 
                                };
      return declaration;
  }

}
