package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

import java.util.Map;

public class ProteinExpressionMassSpec extends DatasetInjector {

  @Override
  public void injectTemplates() {
    setShortAttribution();

    // TODO: How else can we get this??
    String projectName = getPropValue("projectName");
    // String organismAbbrev = getPropValue("organismAbbrev");
    String datasetNamePattern = getPropValue("datasetNamePattern");
    String javaDatasetNamePattern = "";

    if (datasetNamePattern != null) {
      javaDatasetNamePattern = datasetNamePattern.replace("%", ".*");
    }
    else {
      javaDatasetNamePattern = getPropValue("datasetName");
    }
    Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();

    setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
    setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));

    for (String key : globalProps.keySet()) {
      // iterate over keys
      if (key.contains(javaDatasetNamePattern)) {
        if (!key.contains(projectName)) {
          Map<String, String> datasetProps = globalProps.get(key);
          String datasetClassCategory = datasetProps.get("datasetClassCategory");
          String[] parts = key.split("_");
          String extractOrgAbbrev = "";
          extractOrgAbbrev = parts[0];
          setPropValue("organismAbbrev", extractOrgAbbrev);
          // System.out.println(extractOrgAbbrev);
          setPropValue("datasetName", key);
          setPropValue("datasetExtdbName", key);
          setPropValue("datasetClassCategory", datasetClassCategory);
          injectTemplate("jbrowseProteinExpressionMassSpecSampleBuildProps");
        }
      }
    }

    setPropValue("datasetClassCategoryIri", "http://edamontology.org/topic_0108");

    setOrganismAbbrevFromDatasetName();
    String optionalOrganismAbbrev = getPropValue("optionalOrganismAbbrev");

    if (!optionalOrganismAbbrev.equals("")) {
      if (getPropValue("organismAbbrevDisplay").equals("")) {
        setPropValue("organismAbbrevDisplay", optionalOrganismAbbrev);
      }
    }

    String datasetDisplayName = getPropValue("datasetDisplayName");
    String cleanDatasetDisplayName = cleanString(datasetDisplayName);
    setPropValue("cleanDatasetDisplayName", cleanDatasetDisplayName);

    if (datasetNamePattern == null || datasetNamePattern.equals("")) {
      setPropValue("edNameParamValue", getDatasetName());
    }
    else {
      setPropValue("edNameParamValue", datasetNamePattern);
    }

    injectTemplate("proteinExpressionMassSpecGBrowseTrack");

    // setPropValue("gbrowseTrackName", "MassSpecPeptides_" + getDatasetName());
    // injectTemplate("gbrowseTrackCategory");
    // injectTemplate("pbrowseTrackCategory");

    if (getPropValueAsBoolean("hasPTMs")) {
      injectTemplate("proteinExpressionMassSpecPhosphoPBrowseTrack");
    }
    else {
      injectTemplate("proteinExpressionMassSpecPBrowseTrack");
    }

  }

  @Override
  public void addModelReferences() {
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
        "GeneQuestions.GenesByMassSpec");
    // addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecMod");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecDownload");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpec");
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "ProteinExpressionPBrowse");
    if (getPropValueAsBoolean("hasPTMs")) {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question",
          "GeneQuestions.GenesByPTM");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecMod");
    }
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {
        { "species", "metadata for the sample organism, not the aligned organism" },
        { "optionalOrganismAbbrev", "for cases when sample organism is different from the aligned organism" },
        { "hasPTMs", "boolean to flag experiments with post-translational modifications for PBrowse and PTM query model refs" }
    };
    return propertiesDeclaration;
  }

}
