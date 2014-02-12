package org.apidb.apicommon.datasetPresenter;

public class History {
  private Integer buildNumber;
  private String genomeSource;
  private String genomeVersion;
  private String annotationSource;
  private String annotationVersion;
  private String comment;
  private Boolean firstIntroduced;
  
  public void setBuildNumber(Integer buildNumber) {
    this.buildNumber = buildNumber;
  }
   
  public void setGenomeSource(String genomeSource) {
    this.genomeSource = genomeSource;
  }
   
  public void setGenomeVersion(String genomeVersion) {
    this.genomeVersion = genomeVersion;
  }
   
  public void setAnnotationSource(String annotationSource) {
    this.annotationSource = annotationSource;
  }
   
  public void setAnnotationVersion(String annotationVersion) {
    this.annotationVersion = annotationVersion;
  }
  
  public void setComment(String comment) {
    this.comment = comment;
  }
  
  public void setFirstIntroduced(Boolean firstIntroduced) {
    this.firstIntroduced = firstIntroduced;
  }

  public Integer getBuildNumber() {
    return buildNumber;
  }
  
  public String getGenomeSource() {
    return genomeSource;
  }
  
  public String getGenomeVersion() {
    return genomeVersion;
  }  
  
  public String getAnnotationSource() {
    return annotationSource;
  }
  
  public String getAnnotationVersion() {
    return annotationVersion;
  }  
  
  public String getComment() {
    return comment;
  }
  
  public Boolean getFirstIntroduced() {
    return firstIntroduced;
  }
  
}
