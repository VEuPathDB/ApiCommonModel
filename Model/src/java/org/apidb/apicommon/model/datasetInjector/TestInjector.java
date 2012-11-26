package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetInjector.DatasetInjector;

public class TestInjector extends DatasetInjector {

  public void injectTemplates() {


    injectTemplate("test3_template1");

    injectTemplate("test3_template2");
  }

  public void addModelReferences() {
    addWdkReference("GeneRecord", "question", "someQuestion");
    addModelReference("track", "someTrack");
  }
  
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }
}
