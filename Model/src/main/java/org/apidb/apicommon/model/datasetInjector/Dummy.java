package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class Dummy extends DatasetInjector {

  @Override
  public void injectTemplates() {
 
  //setPropValue("summary", getPropValue("summary").replaceAll("\n", " "));
  //setPropValue("summary", getPropValue("summary").replaceAll(" +", " "));
  injectTemplate("jbrowseVcfSampleBuildProps");

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
