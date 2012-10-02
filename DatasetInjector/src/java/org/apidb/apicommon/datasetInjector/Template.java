package org.apidb.apicommon.datasetInjector;

import java.io.InputStream;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Scanner;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Template {

  public static final String TEMPLATE_ANCHOR = "TEMPLATE_ANCHOR";
  public static final String MACRO_START = "\\$\\{";
  public static final String MACRO_END = "\\}";

  static final String nl = System.getProperty("line.separator");

  private Set<String> props = new HashSet<String>();
  String templateText;
  String targetFileName;
  String anchorFileName;
  String name;
  String templateFilePath;

  /*
   * Model construction methods
   */
  public Template(String templateFilePath) {
    this.templateFilePath = templateFilePath;
  }

  void setName(String name) {
    this.name = name;
  }

  // property declaration
  void addProp(String prop) {
    props.add(prop);
  }

  // for testing
  void setProps(Set<String> props) {
    this.props = props;
  }

  void setTemplateText(String templateText) {
    this.templateText = templateText;
  }

  void setTargetFileName(String targetFileName) {
    this.targetFileName = targetFileName;
  }

  void setAnchorFileName(String anchorFileName) {
    this.anchorFileName = anchorFileName;
  }
  
  /*
   * Getters
   */
  String getName() {
    return name;
  }

  Set<String> getProps() {
    return props;
  }

  String getTemplateText() {
    return templateText;
  }

  String getTargetFileName() {
    return targetFileName;
  }

  String getAnchorFileName() {
    return anchorFileName;
  }


  String getTextInstance(Map<String, String> propValues) {
    String textInstance = getTemplateText();
    for (String key : propValues.keySet()) {
      textInstance = textInstance.replaceAll(MACRO_START + key + MACRO_END,
          propValues.get(key));
    }
    return textInstance;
  }

  /*
   * Parsing and model validation methods
   */

  // (lines are pre-trimmed)
  void parsePrelude(String prelude) {
    Scanner scanner = new Scanner(prelude);

    try {
      // first line should be name=
      String line = scanner.nextLine();
      String[] a = line.split("=");
      if (!a[0].equals("name") || a.length != 2)
        throw new UserException("In file '" + templateFilePath + "' the line '"
            + line + "' should be a name=");
      setName(a[1]);

      // second line should be anchorFile=
      line = scanner.nextLine();
      a = line.split("=");
      if (!a[0].equals("anchorFile") || a.length != 2)
        throw new UserException("In file '" + templateFilePath + "' the line '"
            + line + "' should be a anchorFile=");
      setAnchorFileName(a[1]);

      // third line should be targetFile=
      line = scanner.nextLine();
      a = line.split("=");
      if (!a[0].equals("targetFile") || a.length != 2)
        throw new UserException("In file '" + templateFilePath + "' the line '"
            + line + "' should be a targetFile=");
      setTargetFileName(a[1]);

      // the rest should be prop=
      while (scanner.hasNextLine()) {
        line = scanner.nextLine();
        a = line.split("=");
        if (!a[0].equals("prop") || a.length != 2)
          throw new UserException("In file '" + templateFilePath
              + "' the line '" + line + "' should be a prop=");
        addProp(a[1]);
      }
    } finally {
      scanner.close();
    }
  }

  void validateTemplateText() {
    String answer = getTemplateText();
    for (String key : props) {
      answer = answer.replaceAll(MACRO_START + key + MACRO_END, "FOUND");
    }
    Pattern patt = Pattern.compile(MACRO_START + "\\w*" + MACRO_END);
    Matcher m = patt.matcher(answer);
    if (m.find())
      throw new UserException(
          "Template "
              + getName()
              + " in template file "
              + templateFilePath
              + " contains an invalid macro.  The instantiated text is this.  Look for the invalid macro inside it: "
              + answer);

  }

  /*
   * Injection methods
   */
  String getInstancesAsText(List<Map<String, String>> instances) {
    StringBuffer buf = new StringBuffer();
    for (Map<String, String> instance : instances) {
      buf.append(getTextInstance(instance) + nl);
    }
    return buf.toString();
  }
  
  String injectInstancesIntoStream(List<Map<String, String>> instances,
      InputStream targetTextAsStream) {
    return injectTextIntoStream(getInstancesAsText(instances), targetTextAsStream);
  }

  String injectTextIntoStream(String textToInject,
      InputStream targetTextAsStream) {
    Scanner scanner = new Scanner(targetTextAsStream);
    StringBuffer buf = new StringBuffer();
    Pattern patt = Pattern.compile(TEMPLATE_ANCHOR + "\\s+" + name);
    try {
      while (scanner.hasNextLine()) {
        String line = scanner.nextLine();
        buf.append(line + nl);
        Matcher m = patt.matcher(line);
        if (m.find())
          buf.append(nl + textToInject + nl);
      }
    } finally {
      scanner.close();
    }
    return buf.toString();
  }

  boolean validatePropertiesInstance(Map<String, String> propValues) {
    return propValues.keySet().containsAll(getProps());
  }

}
