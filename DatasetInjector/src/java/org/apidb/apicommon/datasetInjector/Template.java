package org.apidb.apicommon.datasetInjector;

import java.io.InputStream;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Scanner;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * A text template, containing embedded macros, with the ability to substitute
 * values into those macros and inject the resulting text into a stream. The
 * Template has a set of property names which specify the macros allowed in the
 * template. It also has anchorFileName which is the path, relative to
 * $PROJECT_HOME, of the file that contains the anchor for this template.
 * 
 * @author steve
 * 
 */
public class Template {

  public static final String TEMPLATE_ANCHOR = "TEMPLATE_ANCHOR";
  public static final String MACRO_START = "\\$\\{";
  public static final String MACRO_END = "\\}";

  static final String nl = System.getProperty("line.separator");

  private Set<String> props = new HashSet<String>();
  private String templateText;
  private String anchorFileName;
  private String name;
  private String templateFilePath;

  /**
   * 
   * @param templateFilePath
   *          The full path to the file that this template was parsed out of.
   */
  public Template(String templateFilePath) {
    this.templateFilePath = templateFilePath;
  }

  void setName(String name) {
    this.name = name;
  }

  /**
   * Add a property name. This allows that name to be used as a macro in the
   * template text.
   * 
   * @param prop
   */
  void addProp(String prop) {
    props.add(prop);
  }

  // for testing
  void setProps(Set<String> props) {
    this.props = props;
  }

  /**
   * Set the template text, which is the text that will be injected, after
   * macros are substituted.
   * 
   * @param templateText
   */
  void setTemplateText(String templateText) {
    this.templateText = templateText;
  }

  /**
   * Set the name of the file, relative to $PROJECT_HOME, in which to find the
   * anchor for this template. Ultimately this file will be transformed into
   * $GUS_HOME with all templates instantiated into it.
   * 
   * @param anchorFileName
   */
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
    String[] splitPath = anchorFileName.split("/lib/");
    return "lib/" + splitPath[1];
  }

  String getAnchorFileName() {
    return anchorFileName;
  }

  /**
   * Confirm that the macros in this template's text use only names found in
   * this template's properties list.
   */
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

  /**
   * Get a TemplateInstance as a text string. Substitute the TemplateInstance's
   * property values into the template's text.
   * 
   * @param instance
   * @return This template's text with macros substituting using the
   *         TemplateInstance's property values.
   */
  String getInstanceAsText(TemplateInstance instance) {
    String textInstance = getTemplateText();
    for (String key : instance.getPropKeys()) {
      textInstance = textInstance.replaceAll(MACRO_START + key + MACRO_END,
          instance.getPropValue(key));
    }
    return textInstance;
  }

  /**
   * Get a list of TemplateInstances as a concatenation of the text string of
   * each.
   * 
   * @param templateInstances
   * @return A text string that is the concatenation of the text instances of the provided TemplateInstances
   * @see #getInstanceAsText(TemplateInstance)
   */
  String getInstancesAsText(List<TemplateInstance> templateInstances) {
    StringBuffer buf = new StringBuffer();
    for (TemplateInstance instance : templateInstances) {
      buf.append(getInstanceAsText(instance) + nl);
    }
    return buf.toString();
  }

  /**
   * Inject the text produced by {@link #getInstancesAsText(List)} into a text
   * stream.
   * 
   * @param instances
   * @param targetTextAsStream
   * @return the target text from the stream as a String with macros substituted in.
   * @see #injectTextIntoStream(String, InputStream)
   */
  String injectInstancesIntoStream(List<TemplateInstance> instances,
      InputStream targetTextAsStream) {
    return injectTextIntoStream(getInstancesAsText(instances),
        targetTextAsStream);
  }

  /**
   * Scan through the provided target text and place the provided injectable text
   * into the stream on the line after an anchor that references this
   * template's name
   * 
   * @param textToInject
   * @param targetTextAsStream
   * @return the target text from the stream as a String with macros substituted in.
   */
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

  /**
   * Validate that the provided set of property values includes all properties required by this template.
   * @param propValues
   * @return true if valid
   */
  boolean validatePropertiesInstance(Map<String, String> propValues) {
    return propValues.keySet().containsAll(getProps());
  }

}
