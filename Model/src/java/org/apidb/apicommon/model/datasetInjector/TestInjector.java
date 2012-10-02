package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetInjector.DatasetInjector;

public class TestInjector extends DatasetInjector {

  public void injectTemplates() {


    injectTemplate("fakeTemplate1");

    injectTemplate("fakeTemplate2");
  }

  public void insertReferences() {
  }
  
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }
}
