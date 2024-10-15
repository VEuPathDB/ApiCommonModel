package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ChIPSeq extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();
      setOrganismAbbrevFromDatasetName();

      injectTemplate("chipSeqCoverageTrackUnlogged");
      //      setPropValue("gbrowseTrackName", getDatasetName() + "CoverageUnlogged");
      //      injectTemplate("gbrowseTrackCategory");

      if (getPropValueAsBoolean("hasCalledPeaks")) {
        String featureName = getPropValue("datasetDisplayName").replace(' ', '_');
        setPropValue ("featureName", featureName);
        injectTemplate("chipSeqPeaks");

        //        setPropValue("gbrowseTrackName", getDatasetName() + "_chipSeqPeaks");
        //        injectTemplate("gbrowseTrackCategory");
    }
        setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
	injectTemplate("jbrowseChIPSeqBuildProps");
  }

  @Override
  public void addModelReferences() { }


    @Override
	public String[][] getPropertiesDeclaration() {
        String[][] propertiesDeclaration = {};
        return propertiesDeclaration;
    }

}
