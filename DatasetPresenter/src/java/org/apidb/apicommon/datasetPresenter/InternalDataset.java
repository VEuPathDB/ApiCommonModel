package org.apidb.apicommon.datasetPresenter;

public class InternalDataset {
  private String name;
  private String namePattern;
  
  public void setName(String name) {
    this.name = name;
  }
  
  public void setDatasetNamePattern(String pattern) {
    this.namePattern = pattern;
  }
  
  String getName() {
    return name;
  }
  
  String getDatasetNamePattern() {
    return namePattern;
  }
}
