package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

import java.util.Map;

public class Vcf extends DatasetInjector {

  @Override
  public void injectTemplates() {

    setPropValue("datasetDisplayName", getPropValue("datasetDisplayName").replaceAll("\n", " "));
    //String datasetName = getPropValue("name");

    String projectName = getPropValue("projectName");
    //String organismAbbrev = getPropValue("organismAbbrev");

    String datasetNamePattern = getPropValue("datasetNamePattern");
    String javaDatasetNamePattern = "";

    if (datasetNamePattern != null) {
      javaDatasetNamePattern = datasetNamePattern.replace("%", ".*");
    }
    else {
      javaDatasetNamePattern = getPropValue("datasetName");
    }

    // setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
    // setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));

    Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();

    for (String key : globalProps.keySet()) {
      // iterate over keys
      if (key.matches(javaDatasetNamePattern)) {
        if (!key.contains(projectName)) {
          //Map<String, String> datasetProps = globalProps.get(key);
          setPropValue("datasetName", key);
          //datasetName = key;
          String[] parts = key.split("_");
          String extractOrgAbbrev = "";
          extractOrgAbbrev = parts[0];
          setPropValue("organismAbbrev", extractOrgAbbrev);
          setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
          setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));

          injectTemplate("jbrowseVcfSampleBuildProps");
        }
      }
    }
  }

  @Override
  public void addModelReferences() {}

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

}
