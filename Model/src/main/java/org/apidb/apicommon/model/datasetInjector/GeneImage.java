package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class GeneImage extends DatasetInjector {

  @Override
  public void injectTemplates() {
      String projectName = getPropValue("projectName");
      setPropValue("includeProjects", projectName + ",UniDB");

      injectTemplate("geneImageGoTermQuestion");
      injectTemplate("geneImageGoTermOntology");
  }

  @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "CellularLocalization");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesByGoTermCL_" + getDatasetName());
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }


}
