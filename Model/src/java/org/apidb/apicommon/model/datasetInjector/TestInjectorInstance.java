package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetInjector.DatasetInjectorInstance;
import java.util.Map;

public class TestInjectorInstance extends DatasetInjectorInstance {

  public void injectTemplates() {

    Map<String, String> propValues = di.getPropValues();

    di.injectTemplate("fakeTemplate1", propValues);

    di.injectTemplate("fakeTemplate2", propValues);
  }

  public void insertReferences() {
  }
  
  // second column is for documentation
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }
}
