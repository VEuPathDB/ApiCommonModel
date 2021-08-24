package org.apidb.apicommon.model.datasetInjector.custom.FungiDB;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class BenzCoexpression extends DatasetInjector {

  @Override
  public void injectTemplates() {
    setShortAttribution();

    String projectName = getPropValue("projectName");
    String datasetName = getDatasetName();

    injectTemplate("coexpressionCategory");
    injectTemplate("coexpressionQuestion");
    injectTemplate("coexpressionQuestion");
    injectTemplate("coexpressionSource");
  }

  @Override
  public void addModelReferences() {
      addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByCoexpressionncraOR74A_array_Benz_Coexpression_RSRC"); 
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
