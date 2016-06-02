package org.apidb.apicommon.model.datasetInjector;

import java.util.Map;
import java.util.HashMap;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class NcbiTaxonomy extends DatasetInjector {

  @Override
  public void injectTemplates() {

    Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();

    Map<String, String> refOrgs = new HashMap<String, String>();

    // Find all reference organisms and inject for organism param default
    for (Map.Entry<String, Map<String, String>> props : globalProps.entrySet()) {
        Map<String, String> map = props.getValue();
        if(map.containsKey("isReferenceStrain") && 
           map.get("isReferenceStrain").toLowerCase().equals("true") &&
           props.getKey().startsWith(map.get("projectName")) ) {
            
            String projectName = map.get("projectName");
            String organismFullName = map.get("organismFullName");


            if(refOrgs.containsKey(projectName)) {
                String refOrgsString = refOrgs.get(projectName);

                refOrgsString = refOrgsString + "," + organismFullName;
                refOrgs.put(projectName, refOrgsString);
                refOrgs.put("EuPathDB", refOrgsString);
            }
            else {
                refOrgs.put(projectName, organismFullName);
                refOrgs.put("EuPathDB", organismFullName);
            }
        }
    }

    
    for (Map.Entry<String, String> refOrg : refOrgs.entrySet()) {
        setPropValue("projectName", refOrg.getKey());
        setPropValue("referenceOrganisms", refOrg.getValue());

        injectTemplate("referenceOrganisms");
    }

  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByTaxon"); 
      addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByTaxon"); 
      addWdkReference("PopsetRecordClasses.PopsetRecordClass", "question", "PopsetQuestions.PopsetByTaxon"); 
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "attribute", "overview"); 
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
