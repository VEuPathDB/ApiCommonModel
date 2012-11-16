package org.apidb.apicommon.datasetInjector;

import org.gusdb.fgputil.xml.Text;

public class HyperLink {
  public enum LinkType {
    INTERNAL, EXTERNAL
  };
  private String url;
  private String description;
  private LinkType linkType;


  public void setUrl(Text url) {
    this.url = url.getText();
  }
  
  public void setDescription(Text description) {
    this.description = description.getText();
  }

  // constrained by RNG schema
  public void setLinkType(String linkType) {
    this.linkType = LinkType.INTERNAL;
    if (linkType.equals("external")) this.linkType = LinkType.EXTERNAL;
  }
  
  public String getUrl() {
    return url;
  }
  
  public String getDescription() {
    return description;
  }
  
  public LinkType getType() {
    return linkType;
  }
  
}
