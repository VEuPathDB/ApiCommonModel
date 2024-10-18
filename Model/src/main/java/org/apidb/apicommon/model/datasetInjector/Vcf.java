package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

import java.util.Map;

public class Vcf extends DatasetInjector {

  @Override
  public void injectTemplates() {

    setPropValue("datasetDisplayName", getPropValue("datasetDisplayName").replaceAll("\n", " "));

    String projectName = getPropValue("projectName");
    String datasetNamePattern = getPropValue("datasetNamePattern");
    String javaDatasetNamePattern = "";

    if (datasetNamePattern != null) {
      javaDatasetNamePattern = datasetNamePattern.replace("%", ".*");
    }
    else {
      javaDatasetNamePattern = getPropValue("datasetName");
    }

    Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();

    for (String key : globalProps.keySet()) {
      // iterate over keys
      if (key.matches(javaDatasetNamePattern)) {
        if (!key.contains(projectName)) {
          setPropValue("datasetName", key);

	String delimiter = "_VBP";
        // Get the index of the delimiter
        int index = key.indexOf(delimiter);
        // Check if the delimiter is found
        if (index != -1) {
            // Extract the substring before the delimiter
            String extractOrgAbbrev = key.substring(0, index);
	    setPropValue("organismAbbrev", extractOrgAbbrev);
        } else {
            System.out.println("Delimiter not found in the string.");
        }

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
