package org.apidb.apicommon.model.datasetInjector.custom.GiardiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class SAGETagsWithGraph extends CusomGenePageExpressionGraphs {

    /**
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
      injectTemplate("sageTagExpressionGraphAttributes");
      injectTemplate("pathwayGraphs");
  }

    **/
  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "profile_graph", "Sage::McArthur");
  }



}
