package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

public class TemplateSet {
  
  Map<String, Template> nameToTemplate = new HashMap<String, Template>();
  Map<String, Set<String>> anchorFileNameToTemplateNames = new HashMap<String, Set<String>>();
  
  Template getTemplateByName(String name) {
    return nameToTemplate.get(name);
  }
  
  Set<String> getAnchorFileNames() {
    return anchorFileNameToTemplateNames.keySet();
  }
  
  Set<String> getTemplateNamesByAnchorFileName(String anchorFileName) {
    return anchorFileNameToTemplateNames.get(anchorFileName);
  }

  void parseTemplatesFile(String templatesFilePath) {
    BufferedReader in = null;
  
    try {
      try {
        in = new BufferedReader(new FileReader(templatesFilePath));
  
        StringBuffer templateStrBuf = new StringBuffer();
        boolean foundFirst = false;
        while (in.ready()) {
          String line = in.readLine();
          if (!foundFirst) {
            line = line.trim();
            if (line.startsWith("#"))
              continue;
            if (line.length() == 0)
              continue;
            if (line.equals(Template.TEMPLATE_START)) {
              foundFirst = true;
              templateStrBuf = new StringBuffer();
            } else {
              throw new UserException("Templates file " + templatesFilePath
                  + " must start with " + Template.TEMPLATE_START);
            }
          } else {
            if (line.trim().equals(Template.TEMPLATE_START)) {
              Template template = Template.parseSingleTemplateString(
                  templateStrBuf.toString(), templatesFilePath);
              template.validateTemplateText();
              nameToTemplate.put(template.getName(), template);
              templateStrBuf = new StringBuffer();
            } else {
              templateStrBuf.append(line + Template.nl);
            }
          }
        }
        Template template = Template.parseSingleTemplateString(
            templateStrBuf.toString(), templatesFilePath);
        nameToTemplate.put(template.getName(), template);
      } catch (FileNotFoundException ex) {
        throw new UserException("Templates file " + templatesFilePath
            + " not found");
      } finally {
        if (in != null)
          in.close();
      }
    } catch (IOException ex) {
      throw new UnexpectedException(ex);
    }
  }

}
