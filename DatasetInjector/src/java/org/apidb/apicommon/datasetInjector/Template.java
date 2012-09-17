package org.apidb.apicommon.datasetInjector;

import java.util.HashSet;
import java.util.Set;

public class Template {
  
  private Set<String> props = new HashSet<String>();
  String templateText;
  String templateTargetFileName;
  
  // property declaration
  public void addProp(String prop) {
    props.add(prop);
  }

  public void setTemplateText(String templateText) {
    this.templateText = templateText;
  }
  
  public void setTemplateTargetFileName(String templateTargetFileName) {
    this.templateTargetFileName = templateTargetFileName;
  }
}
