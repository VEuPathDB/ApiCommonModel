package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Sequences extends DatasetInjector {

  @Override
  public void injectTemplates() {

      setShortAttribution();
      setOrganismAbbrevFromDatasetName();
      String organismAbbrevDisplay = getPropValue("organismAbbrevDisplay");
      setPropValue("organismAbbrevDisplay", organismAbbrevDisplay.replace(":", ""));

      injectTemplate("sequenceGBrowseTrack");

      setPropValue("gbrowseTrackName", "Sequences_" + getDatasetName() );
      injectTemplate("gbrowseTrackCategory");

  }

  @Override
  public void addModelReferences() {
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Taxonomy");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "SequencePieces");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Aliases");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Centromere");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "SequenceComments");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {
      };
      return propertiesDeclaration;
  }

}
