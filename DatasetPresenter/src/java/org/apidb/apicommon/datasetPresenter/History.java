package org.apidb.apicommon.datasetPresenter;

public class History {
  private Integer buildNumber;
  private String genomeSource;
  private String genomeVersion;
  private String comment;
  
  public History(Integer buildNumber, String genomeSource, String genomeVersion, String comment) {
    
    this.buildNumber = buildNumber;
    this.genomeSource = genomeSource;
    this.genomeVersion = genomeVersion;
    this.comment = comment;
  }
  
  Integer getBuildNumber() {
    return buildNumber;
  }
  
  String getGenomeSource() {
    return genomeSource;
  }
  
  String getGenomeVersion() {
    return genomeVersion;
  }  
  
  String getComment() {
    return comment;
  }
  
}
