package org.apidb.apicommon.datasetInjector;

import java.util.HashSet;
import java.util.Scanner;
import java.util.Set;

public class Template {

  public static final String TEMPLATE_TEXT_START = ">templateTextStart<";
  public static final String TEMPLATE_TEXT_END = ">templateTextEnd<";
  private static final String nl = System.getProperty("line.separator");

  private Set<String> props = new HashSet<String>();
  String templateText;
  String templateTargetFileName;
  String name;

  public void setName(String name) {
    this.name = name;
  }

  public String getName() {
    return name;
  }

  // property declaration
  public void addProp(String prop) {
    props.add(prop);
  }

  public Set<String> getProps() {
    return props;
  }

  public void setTemplateText(String templateText) {
    this.templateText = templateText;
  }

  public String getTemplateText() {
    return templateText;
  }

  public void setTemplateTargetFileName(String templateTargetFileName) {
    this.templateTargetFileName = templateTargetFileName;
  }

  public String getTemplateTargetFileName() {
    return templateTargetFileName;
  }

  public static Template parseSingleTemplateString(String templateInputString,
      String templateFilePath) {
    String[] parts = splitTemplateString(templateInputString, templateFilePath);
    Template template = new Template();
    parsePrelude(parts[0], template, templateFilePath);
    template.setTemplateText(parts[1]);
    return template;
  }

  // expects a string ending with >templateTextEnd<
  public static String[] splitTemplateString(String templateInputString, String templateFilePath) {
    Scanner scanner = new Scanner(templateInputString);
    StringBuffer prelude = new StringBuffer();
    StringBuffer templateText = null;
    try {
      
      // prelude and template text
      while (scanner.hasNextLine()) {
        String line = scanner.nextLine();
        if (templateText == null) {
          line.trim();
          if (line.startsWith("#")) continue;
          if (line.length() == 0) continue;
          if (line.equals(TEMPLATE_TEXT_START)) {
            templateText = new StringBuffer();
          } else {
            prelude.append(line + nl);
          }
        } else {
          if (line.equals(TEMPLATE_TEXT_END))
            break;
          templateText.append(line + nl);
        }
      }
      
      // past end of template text
      while (scanner.hasNextLine()) {
        String line = scanner.nextLine();
        if (line.startsWith("#")) continue;
        if (line.length() == 0) continue;
        throw new UserException("Template file '" + templateFilePath + "' has an invalid template.  The line '" + line + "' is outside a " + TEMPLATE_TEXT_END);
      }
      
      String[] answer = { prelude.toString(), templateText.toString() };
      return answer;
    } finally {
      scanner.close();
    }
  }

  // (lines are pre-trimmed)
  public static void parsePrelude(String prelude, Template targetTemplate,
      String templateFilePath) {
    Scanner scanner = new Scanner(prelude);

    try {
      // first line should be name=
      String line = scanner.nextLine();
      String[] a = line.split("=");
      if (!a[0].equals("name") || a.length != 2)
        throw new UserException("In file '" + templateFilePath + "' the line '"
            + line + "' should be a name=");
      targetTemplate.setName(a[1]);

      // second line should be targetFile=
      line = scanner.nextLine();
      a = line.split("=");
      if (!a[0].equals("targetFile") || a.length != 2)
        throw new UserException("In file '" + templateFilePath + "' the line '"
            + line + "' should be a targetFile=");
      targetTemplate.setTemplateTargetFileName(a[1]);

      // the rest should be prop=
      while (scanner.hasNextLine()) {
        line = scanner.nextLine();
        a = line.split("=");
        if (!a[0].equals("prop") || a.length != 2)
          throw new UserException("In file '" + templateFilePath
              + "' the line '" + line + "' should be a prop=");
        targetTemplate.addProp(a[1]);
      }
    } finally {
      scanner.close();
    }
  }

}
