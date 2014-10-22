package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.SAGETags;

public class SAGETagsWithGraph extends SAGETags {

  @Override
  public void injectTemplates() {
      String description = getPropValue("datasetDescrip");

      String datasetName = getDatasetName();
      setPropValue("datasetDescrip", description.replace("'", ""));
      
      String xAxis = getPropValue("graphXAxisSamplesDescription");
      setPropValue("graphXAxisSamplesDescription", xAxis.replace("'", ""));

      String yAxis = getPropValue("graphYAxisDescription");
      setPropValue("graphYAxisDescription", yAxis.replace("'", ""));

      setPropValue("exprGraphAttr", datasetName + "_expr_graph");

      setPropValue("isGraphCustom", "true");
      injectTemplate("genePageGraphDescriptions");
      injectTemplate("datasetExampleGraphDescriptions");

      injectTemplate("sageTagAttributesList");
      injectTemplate("sageTagAttributesListR");
      injectTemplate("sageTagAttributeCategory");
      injectTemplate("sageTagExpressionGraphAttributes");
      injectTemplate("pathwayGraphs");
  }

  @Override
  public void addModelReferences() {
      // add all references from SAGETags first
      super.addModelReferences();
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Sage::McArthur");
  }

  // second column is for documentation
  @Override
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
