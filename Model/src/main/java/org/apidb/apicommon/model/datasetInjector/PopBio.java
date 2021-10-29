package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class PopBio extends DatasetInjector {

  @Override
  public void injectTemplates() {
      injectTemplate("datasetCategory");
  }

  @Override
  public void addModelReferences() {
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
    String[][] propertiesDeclaration = {};
    return propertiesDeclaration;
  }

}
