package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ProteinExpressionMassSpec extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();

      // TODO:  How else can we get this??
      setPropValue("datasetClassCategoryIri", "http://edamontology.org/topic_0108");

      setOrganismAbbrevFromDatasetName();
      String optionalOrganismAbbrev  = getPropValue("optionalOrganismAbbrev");

      if (!optionalOrganismAbbrev.equals("")) {
        if (getPropValue("organismAbbrevDisplay").equals("")) {
          setPropValue("organismAbbrevDisplay", optionalOrganismAbbrev);
        }
      }

      String datasetDisplayName = getPropValue("datasetDisplayName");
      String cleanDatasetDisplayName = cleanString(datasetDisplayName);
      setPropValue("cleanDatasetDisplayName",cleanDatasetDisplayName);

       String datasetNamePattern = getPropValue("datasetNamePattern");

      if (datasetNamePattern == null || datasetNamePattern.equals("")) {
          setPropValue("edNameParamValue", getDatasetName());
      }
      else {
          setPropValue("edNameParamValue",datasetNamePattern);
      }


      injectTemplate("proteinExpressionMassSpecGBrowseTrack");

      //      setPropValue("gbrowseTrackName", "MassSpecPeptides_" + getDatasetName());
      //      injectTemplate("gbrowseTrackCategory");
      //      injectTemplate("pbrowseTrackCategory");

      if(getPropValueAsBoolean("hasPTMs")) {
          injectTemplate("proteinExpressionMassSpecPhosphoPBrowseTrack");
      }
      else {
          injectTemplate("proteinExpressionMassSpecPBrowseTrack");
      }

      //String presenterId = getPropValue("presenterId");
      //String datasetClassCategory = getPropValue("category");
      String organismAbbrev = getPropValue("organismAbbrev");
      String datasetName = getPropValue("datasetName");


      String dsExtName = organismAbbrev + datasetName;
      //setPropValue("datasetExtdbName", getPropValue("edNameParamValue"));
      if (datasetName.startsWith("_")) {
      setPropValue("datasetExtdbName", dsExtName);
      }
      else {
      setPropValue("datasetExtdbName", datasetName);
      }
      setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
      setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));
      injectTemplate("jbrowseProteinExpressionMassSpecSampleBuildProps");

  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByMassSpec");
      //addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecMod");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecDownload");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpec");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ProteinExpressionPBrowse");
      if (getPropValueAsBoolean("hasPTMs")) {
        addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByPTM");
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecMod");
      }
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {{"species", "metadata for the sample organism, not the aligned organism"},
                                          {"optionalOrganismAbbrev","for cases when sample organism is different from the aligned organism"},
                                          {"hasPTMs","boolean to flag experiments with post-translational modifications for PBrowse and PTM query model refs"},
      };
      return propertiesDeclaration;
  }

}
