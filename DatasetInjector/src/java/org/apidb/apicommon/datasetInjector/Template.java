package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Scanner;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Template {

  public static final String TEMPLATE_START = "[templateStart]";
  public static final String TEMPLATE_TEXT_START = ">templateTextStart<";
  public static final String TEMPLATE_TEXT_END = ">templateTextEnd<";
  public static final String TEMPLATE_ANCHOR = "TEMPLATE_ANCHOR";
  public static final String MACRO_START = "\\$\\{";
  public static final String MACRO_END = "\\}";

  private static final String nl = System.getProperty("line.separator");

  private Set<String> props = new HashSet<String>();
  String templateText;
  String targetFileName;
  String name;
  String templateFilePath;

  /*
   * Model construction methods
   */
  public Template(String templateFilePath) {
    this.templateFilePath = templateFilePath;
  }

  public void setName(String name) {
    this.name = name;
  }

  // property declaration
  public void addProp(String prop) {
    props.add(prop);
  }

  // for testing
  public void setProps(Set<String> props) {
    this.props = props;
  }

  public void setTemplateText(String templateText) {
    this.templateText = templateText;
  }

  public void setTemplateTargetFileName(String templateTargetFileName) {
    this.targetFileName = templateTargetFileName;
  }

  /*
   * Getters
   */
  public String getName() {
    return name;
  }

  public Set<String> getProps() {
    return props;
  }

  public String getTemplateText() {
    return templateText;
  }

  public String getTemplateTargetFileName() {
    return targetFileName;
  }

  public String getTextInstance(Map<String, String> propValues) {
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
  public void parsePrelude(String prelude) {
    Scanner scanner = new Scanner(prelude);

    try {
      // first line should be name=
      String line = scanner.nextLine();
      String[] a = line.split("=");
      if (!a[0].equals("name") || a.length != 2)
        throw new UserException("In file '" + templateFilePath + "' the line '"
            + line + "' should be a name=");
      setName(a[1]);

      // second line should be targetFile=
      line = scanner.nextLine();
      a = line.split("=");
      if (!a[0].equals("targetFile") || a.length != 2)
        throw new UserException("In file '" + templateFilePath + "' the line '"
            + line + "' should be a targetFile=");
      setTemplateTargetFileName(a[1]);

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

  public void validateTemplateText() {
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
  public String injectInstancesIntoStream(Set<Map<String, String>> instances,
      InputStream targetTextAsStream) {
    StringBuffer buf = new StringBuffer();
    for (Map<String, String> instance : instances) {
      buf.append(getTextInstance(instance) + nl);
    }
    return injectTextIntoStream(buf.toString(), targetTextAsStream);
  }

  public String injectTextIntoStream(String textToInject,
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

  public boolean validatePropertiesInstance(Map<String, String> propValues) {
    return propValues.keySet().containsAll(getProps());
  }

  // /////////// Static methods //////////

  public static Template parseSingleTemplateString(String templateInputString,
      String templateFilePath) {
    String[] parts = splitTemplateString(templateInputString, templateFilePath);
    Template template = new Template(templateFilePath);
    template.parsePrelude(parts[0]);
    template.setTemplateText(parts[1]);
    template.validateTemplateText();
    return template;
  }

  // expects a string ending with >templateTextEnd<
  public static String[] splitTemplateString(String templateInputString,
      String templateFilePath) {
    Scanner scanner = new Scanner(templateInputString);
    StringBuffer prelude = new StringBuffer();
    StringBuffer templateText = null;
    try {

      // prelude and template text
      while (scanner.hasNextLine()) {
        String line = scanner.nextLine();
        if (templateText == null) {
          line = line.trim();
          if (line.startsWith("#"))
            continue;
          if (line.length() == 0)
            continue;
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
        if (line.startsWith("#"))
          continue;
        if (line.length() == 0)
          continue;
        throw new UserException("Template file '" + templateFilePath
            + "' has an invalid template.  The line '" + line
            + "' is outside a " + TEMPLATE_TEXT_END);
      }

      String[] answer = { prelude.toString(), templateText.toString() };
      return answer;
    } finally {
      scanner.close();
    }
  }

  public static Map<String, Template> parseTemplatesFile(
      String templatesFilePath) {
    BufferedReader in = null;
    HashMap<String, Template> templatesByName = new HashMap<String, Template>();

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
              templatesByName.put(template.getName(), template);
              templateStrBuf = new StringBuffer();
            } else {
              templateStrBuf.append(line + nl);
            }
          }
        }
        Template template = Template.parseSingleTemplateString(
            templateStrBuf.toString(), templatesFilePath);
        templatesByName.put(template.getName(), template);
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
    return templatesByName;
  }

}
