package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.Scanner;

public class TemplateSetParser {
  
  public static final String TEMPLATE_START = "[templateStart]";
  public static final String TEMPLATE_TEXT_START = ">templateTextStart<";
  public static final String TEMPLATE_TEXT_END = ">templateTextEnd<";
  static final String nl = System.getProperty("line.separator");

  static void parseTemplatesFile(TemplateSet targetTemplateSet, String templatesFilePath) {
    BufferedReader in = null;
  
    try {
      try {
        in = new BufferedReader(new FileReader(templatesFilePath));
  
        StringBuffer templateStrBuf = new StringBuffer();
        boolean foundFirst = false;
        while (in.ready()) {
          String line = in.readLine();
          if (line == null) break;   // to dodge findbugs error
          if (!foundFirst) {
            line = line.trim();
            if (line.startsWith("#"))
              continue;
            if (line.length() == 0)
              continue;
            if (line.equals(TEMPLATE_START)) {
              foundFirst = true;
              templateStrBuf = new StringBuffer();
            } else {
              throw new UserException("Templates file " + templatesFilePath
                  + " must start with " + TEMPLATE_START);
            }
          } else {
            if (line.trim().equals(TEMPLATE_START)) {
              processTemplate(targetTemplateSet, templateStrBuf.toString(), templatesFilePath);
              templateStrBuf = new StringBuffer();
            } else {
              templateStrBuf.append(line + Template.nl);
            }
          }
        }
        processTemplate(targetTemplateSet, templateStrBuf.toString(), templatesFilePath);
        
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
  
  static void processTemplate(TemplateSet targetTemplateSet, String templateStr, String templatesFilePath) {
    Template template = parseSingleTemplateString(
        templateStr, templatesFilePath);
    template.validateTemplateText();
    targetTemplateSet.addTemplate(template);
  }

  static Template parseSingleTemplateString(String templateInputString,
      String templateFilePath) {
    String[] parts = splitTemplateString(templateInputString, templateFilePath);
    Template template = new Template(templateFilePath);
    template.parsePrelude(parts[0]);
    template.setTemplateText(parts[1]);
    template.validateTemplateText();
    return template;
  }

  // expects a string ending with >templateTextEnd<
  static String[] splitTemplateString(String templateInputString,
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

}
