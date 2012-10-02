package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class TemplateSet {
  
  Map<String, Template> nameToTemplate = new HashMap<String, Template>();
  Map<String, Set<String>> anchorFileNameToTemplateNames = new HashMap<String, Set<String>>();
  
  void addTemplate(Template template) {
    nameToTemplate.put(template.getName(), template);
    String anchorFileName = template.getAnchorFileName();
    if (!anchorFileNameToTemplateNames.containsKey(anchorFileName)) {
      anchorFileNameToTemplateNames.put(anchorFileName, new HashSet<String>());
    }
    anchorFileNameToTemplateNames.get(anchorFileName).add(template.getName());
  }
  
  Template getTemplateByName(String name) {
    return nameToTemplate.get(name);
  }
  
  Set<String> getAnchorFileNames() {
    return anchorFileNameToTemplateNames.keySet();
  }
  
  Set<String> getTemplateNamesByAnchorFileName(String anchorFileName) {
    return anchorFileNameToTemplateNames.get(anchorFileName);
  }
}
