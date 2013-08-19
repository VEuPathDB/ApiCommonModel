package org.apidb.apicommon.datasetPresenter;

import org.gusdb.fgputil.xml.Text;

public class HyperLink {
  private String url;
  private String text;
  private String description;

  public void setUrl(Text url) {
    this.url = url.getText();
  }
  
  public void setText(Text text) {
    this.text = text.getText();
  }
  
  public String getUrl() {
    return url;
  }
  
  public String getText() {
    return text;
  }

  public String getDescription() {
    return description;
  }
  
  
}
