package org.apidb.apicommon.model.datasetInjector;

import java.util.Map;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import org.gusdb.wdk.model.WdkRuntimeException;

// Should really just be called Genome
public class UnannotatedGenome extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setOrgProperties();
      injectTemplate("jbrowseCommon");

      String projectName = getPropValue("projectName");
      String organismAbbrev = getPropValue("organismAbbrev");

      Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();
      String orgPropsKey = projectName + ":" + organismAbbrev + "_RSRC";
      Map<String, String> orgProps = globalProps.get(orgPropsKey);
      
      if (orgProps == null) throw new WdkRuntimeException("No global property set for " + orgPropsKey);


      for (Map.Entry<String, String> entry : orgProps.entrySet()) {
          setPropValue(entry.getKey(), entry.getValue());
      }

      injectTemplate("jbrowseOrganismBuildProps");
  }


    public void setOrgProperties() {
      String projectName = getPropValue("projectName");
      String organismAbbrev = getPropValue("organismAbbrev");

      Map<String, Map<String, String>> globalProps = getGlobalDatasetProperties();
      String orgPropsKey = projectName + ":" + organismAbbrev + "_RSRC";
      Map<String, String> orgProps = globalProps.get(orgPropsKey);
      
      if (orgProps == null) throw new WdkRuntimeException("No global property set for " + orgPropsKey);
      String organismNameForFiles = orgProps.get("organismNameForFiles");

      setPropValue("organismNameForFiles", organismNameForFiles);

      String organismFullName = orgProps.get("organismFullName");
      String strainAbbrev = orgProps.get("strainAbbrev");

      String datasetDisplayName = getPropValue("datasetDisplayName");

      if(datasetDisplayName.toLowerCase().equals("genome gequence") || datasetDisplayName.toLowerCase().equals("genome sequence and annotation")) {
          if(organismFullName.contains(strainAbbrev)) {
              datasetDisplayName = "Genome Sequence and Annotation for <i>" + replaceLast(organismFullName, strainAbbrev, "") + "</i> " + strainAbbrev;
          }
          else {
              String[] arr = organismFullName.split("\\s+");
              datasetDisplayName = "Genome Sequence and Annotation for <i>" + arr[0] + " " + arr[1] + "  "  + "</i> " + strainAbbrev;
          }
      }

      setPropValue("datasetDisplayName", datasetDisplayName);
    }

    public static String replaceLast(String text, String regex, String replacement) {
        return text.replaceFirst("(?s)(.*)" + regex, "$1" + replacement);
    }


  @Override
  public void addModelReferences() {
    setOrgProperties();

    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "attribute", "overview");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequenceBySourceId");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "question", "GenomicSequenceQuestions.SequencesByTaxon");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Taxonomy");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "SequencePieces");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Aliases");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "Centromere");
    addWdkReference("SequenceRecordClasses.SequenceRecordClass", "table", "SequenceComments");


    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "attribute", "overview");
    addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansBySourceId");

    if (!(getPropValue("projectName").equals("HostDB"))){
	addWdkReference("DynSpanRecordClasses.DynSpanRecordClass", "question", "SpanQuestions.DynSpansByMotifSearch");
    }

    addWdkReference("OrganismRecordClasses.OrganismRecordClass", "table", "SequenceCounts");
    addWdkReference("OrganismRecordClasses.OrganismRecordClass", "table", "GeneCounts");
    addWdkReference("OrganismRecordClasses.OrganismRecordClass", "table", "GenomeSequencingAndAnnotationAttribution");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
