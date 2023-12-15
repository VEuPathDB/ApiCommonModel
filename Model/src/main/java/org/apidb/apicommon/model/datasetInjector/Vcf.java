package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

import java.util.Map;

public class Vcf extends DatasetInjector {

  @Override
  public void injectTemplates() {
	String datasetName = getPropValue("name");
        //setPropValue("datasetName", datasetName);

      	String projectName = getPropValue("projectName");
      	String organismAbbrev = getPropValue("organismAbbrev");

	String datasetNamePattern = getPropValue("datasetNamePattern");
      	String javaDatasetNamePattern = "";

      	if (datasetNamePattern != null){
        	javaDatasetNamePattern = datasetNamePattern.replace("%", ".*");
      	}
      	else{
        	//javaDatasetNamePattern = getPropValue("name");
        	String fullName = organismAbbrev + "_" + datasetName + "_ebi_VCF_RSRC";
		setPropValue("datasetName", fullName);
        setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
        setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));

		injectTemplate("jbrowseVcfSampleBuildProps");
      	}
      	Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();
        //setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
        //setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));



        for (String key : globalProps.keySet()){
        //iterate over keys
        if (key.matches(javaDatasetNamePattern)){
                if (!key.contains(projectName)){
                        Map<String, String> datasetProps = globalProps.get(key);
                        //String datasetClassCategory = datasetProps.get("datasetClassCategory");
			//System.out.println("KEY=" + key);
			setPropValue("datasetName", key);
			datasetName = key;
			//System.out.println("DATASETNAME=" + datasetName);
                        String[] parts = key.split("_");
                        String extractOrgAbbrev = "";
                        extractOrgAbbrev = parts[0];
                        setPropValue("organismAbbrev", extractOrgAbbrev );
        		setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
        		setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));

                        injectTemplate("jbrowseVcfSampleBuildProps");
                        }
                }
        }


  }

  @Override
  public void addModelReferences() {
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
