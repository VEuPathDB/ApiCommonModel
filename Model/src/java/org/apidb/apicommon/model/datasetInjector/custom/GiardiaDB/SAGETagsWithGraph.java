package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.SAGETags;

public class SAGETagsWithGraph extends SAGETags {

  public void injectTemplates() {
      String description = getPropValue("datasetDescrip");
      setPropValue("datasetDescrip", description.replace("'", ""));

      
      String xAxis = getPropValue("graphXAxisSamplesDescription");
      setPropValue("graphXAxisSamplesDescription", xAxis.replace("'", ""));

      String yAxis = getPropValue("graphYAxisDescription");
      setPropValue("graphYAxisDescription", yAxis.replace("'", ""));


      setPropValue("isGraphCustom", "true");
      injectTemplate("genePageGraphDescriptions");
  }


  public void addModelReferences() {
      // add all references from SAGETags first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Sage::McArthur");
  }


  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {    {"graphModule", ""},
                                              {"graphXAxisSamplesDescription", ""},
                                              {"graphYAxisDescription", ""},
                                              {"graphVisibleParts", ""},
                                              {"graphPriorityOrderGrouping", ""},
      };
    return propertiesDeclaration;
  }


}
