package org.apidb.apicommon.datasetInjector;

public abstract class DatasetInjectorInstance {

  protected DatasetInjector di;

  public void setDatasetInjector(DatasetInjector di) {
    this.di = di;
  }

  public abstract String[][] getPropertiesDeclaration();

  public abstract void insertReferences();

  public abstract void injectTemplates();

}
