package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * A set of Templates, typically those parsed from a templates file.
 * 
 * @author steve
 * 
 */
public class TemplateSet {

  Map<String, Template> nameToTemplate = new HashMap<String, Template>();
  Map<String, Set<String>> anchorFileNameToTemplateNames = new HashMap<String, Set<String>>();


  /**
   * Add a Template to this set. Must have a unique template name.
   * 
   * @param template
   */
  void addTemplate(Template template, String templatesFilePath) {
    if (nameToTemplate.containsKey(template.getName()))
      throw new UserException("Duplicate template found: " + template.getName()
          + Template.nl + "Templates file: " + templatesFilePath);
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

  /**
   * Get the set of anchor file name mentioned by all the Templates in this set.
   * (An anchor file may contain anchors for more than one Template.)
   * 
   */
  Set<String> getAnchorFileNames() {
    return anchorFileNameToTemplateNames.keySet();
  }

  /**
   * Get the names of the Templates in this set that belong in the provided
   * anchorFileName.
   * 
   * @param anchorFileName
   */
  Set<String> getTemplateNamesByAnchorFileName(String anchorFileName) {
    return anchorFileNameToTemplateNames.get(anchorFileName);
  }
  
  int getSize() {
    return nameToTemplate.size();
  }
}
