package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;

public class DatasetPresenterProcessor {

  private static final String nl = System.getProperty("line.separator");

  // ////// static methods //////////////

  public static void processDatasetPresenterSet(
      DatasetPresenterSet datasetPresenterSet, String templatesFilePath) {

    Map<String, Template> templateNameToTemplate = Template.parseTemplatesFile(templatesFilePath);

    DatasetInjectorSet datasetInjectorSet = datasetPresenterSet.getDatasetInjectorSet();

    Map<String, Set<Map<String, String>>> templateInstances = datasetInjectorSet.getTemplateInstances();

    for (String templateName : templateInstances.keySet()) {
      Template template = templateNameToTemplate.get(templateName);
      String templateTargetFileName = template.getTemplateTargetFileName();
      String proj_home = System.getenv("PROJECT_HOME");
      String gus_home = System.getenv("GUS_HOME");
      
      try {
        FileInputStream targetFileStream = new FileInputStream(
            templateTargetFileName);

        String targetFileWithInjection = template.injectInstancesIntoStream(
            templateInstances.get(templateName), targetFileStream);
        FileWriter fw = new FileWriter("");
        BufferedWriter bw = new BufferedWriter(fw);
        bw.write(targetFileWithInjection);
        bw.close();
      } catch (FileNotFoundException ex) {
        throw new UserException("Can't find template anchors file "
            + templateTargetFileName);
      } catch (IOException ex) {
        throw new UserException("Can't write to template target file" + "", ex);
      }
    }
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

    Map<String, Template> templatesByName = Template.parseTemplatesFile("lib/dst/rnaSeqTemplates.dst");
  }

}
