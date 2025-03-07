package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Cellxgene extends DatasetInjector {

    @Override
	public void injectTemplates() {
    }

    @Override
  public void addModelReferences() {
    addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "Cellxgene");
    addWdkReference("TranscriptRecordClasses.TranscriptRecordClass", "question", "GeneQuestions.GenesBySingleCell");
  }

  // second column is for documentation
    @Override
	public String[][] getPropertiesDeclaration() {
        String[][] propertiesDeclaration = {};
        return propertiesDeclaration;
    }

  
}
