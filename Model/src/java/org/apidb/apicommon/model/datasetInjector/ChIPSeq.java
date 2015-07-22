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
      } 
      else if(scale.toLowerCase().equals("linear")) {
          injectTemplate("chipSeqCoverageTrackUnlogged");
      } 
      else if(scale.toLowerCase().equals("both")) {
          injectTemplate("chipSeqCoverageTrack");
          injectTemplate("chipSeqCoverageTrackUnlogged");
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
