package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class MassSpecMetabolomicsAmphotericinB extends DatasetInjector {

  @Override
  public void injectTemplates() {

      String description = getPropValue("summary");
      if (description.equals("")) {
	  description = getPropValue("datasetDescrip");
      } 
      setPropValue("datasetDescrip", description.replace("'", ""));
      
      String xAxis = getPropValue("graphXAxisSamplesDescription");
      setPropValue("graphXAxisSamplesDescription", xAxis.replace("'", ""));

      String yAxis = getPropValue("graphYAxisDescription");
      setPropValue("graphYAxisDescription", yAxis.replace("'", ""));

      setPropValue("isGraphCustom", "true");

      String projectName = getPropValue("projectName");
      setPropValue("includeProjectsExcludeEuPathDB", projectName + ",UniDB");

      injectTemplate("compoundPageGraphDescriptions");
      injectTemplate("datasetExampleGraphDescriptions");
      injectTemplate("metabolomicsGraphAttributes");
      injectTemplate("metaboliteGraphTextAttributeCategory");

      setPropValue("searchCategory", "searchCategory-metabolomics-fold-change");
      setPropValue("questionName", "CompoundQuestions.CompoundsByFoldChangeAmphotericinB");

      setPropValue("searchCategory", "searchCategory-metabolomics-percentile");
      setPropValue("questionName", "CompoundQuestions.CompoundsByPercentileAmphotericinB");

  }

  @Override
  public void addModelReferences() {

      addWdkReference("CompoundRecordClasses.CompoundRecordClass", "profile_graph", getPropValue("graphModule"));
      addWdkReference("CompoundRecordClasses.CompoundRecordClass", "question", "CompoundQuestions.CompoundsByFoldChangeAmphotericinB");
      addWdkReference("CompoundRecordClasses.CompoundRecordClass", "question", "CompoundQuestions.CompoundsByPercentileAmphotericinB");
      addWdkReference("CompoundRecordClasses.CompoundRecordClass", "table", "MassSpecGraphs");
      addWdkReference("CompoundRecordClasses.CompoundRecordClass", "table", "MassSpecGraphsDataTable");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {    {"graphModule", ""},
                                              {"graphXAxisSamplesDescription", ""},
                                              {"graphYAxisDescription", ""},
                                              {"graphPriorityOrderGrouping", ""},
      };

    return propertiesDeclaration;
  }


}

