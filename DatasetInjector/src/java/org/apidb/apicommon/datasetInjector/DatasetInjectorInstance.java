package org.apidb.apicommon.datasetInjector;

public interface DatasetInjectorInstance {
  
  public String[][] getPropertiesDeclaration();
  
  public void insertReferences();
  
  public void injectTemplates();
  
  public void setDatasetInjector(DatasetInjector datasetInjector);

}
