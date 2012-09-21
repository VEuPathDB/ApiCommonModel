package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;
import org.gusdb.fgputil.runtime.GusHome;

public class DatasetInjectorSet {

  private static final String nl = System.getProperty("line.separator");
  private static final String GUS_HOME = GusHome.getGusHome();

  private Map<String, Template> templatesByName;
  private Map<String, Template> templateInstancesByName;

  public DatasetInjectorSet(Map<String, Template> templatesByName) {
    this.templatesByName = templatesByName;
  }

  // ////// static methods //////////////

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

  private static Options declareOptions() {
    Options options = new Options();

    OptionGroup actions = new OptionGroup();
    Option template = new Option("t", "Inject templates");
    actions.addOption(template);

    Option ref = new Option("r", "Make references");
    actions.addOption(ref);

    options.addOptionGroup(actions);

    CliUtil.addOption(options, "presenterFiles",
        "one or more dataset presenter xml files", true, true);

    return options;
  }

  private static String getUsageNotes() {
    return

    nl + "";
  }

  public static CommandLine getCmdLine(String[] args) {
    String cmdName = System.getProperty("cmdName");

    // parse command line
    Options options = declareOptions();
    String cmdlineSyntax = cmdName
        + "<-t | -r> -presenterFiles presenterFile1 ...";
    String cmdDescrip = "Read provided dataset presenter files and either inject templates or make dataset references";
    CommandLine cmdLine = CliUtil.parseOptions(cmdlineSyntax, cmdDescrip,
        getUsageNotes(), options, args);

    return cmdLine;
  }

  public static void main(String[] args) throws Exception {

    CommandLine cmdLine = getCmdLine(args);

    Map<String, Template> templatesByName = parseTemplatesFile("lib/dst/rnaSeqTemplates.dst");
    DatasetInjectorSet dis = new DatasetInjectorSet(templatesByName);
  }

}
