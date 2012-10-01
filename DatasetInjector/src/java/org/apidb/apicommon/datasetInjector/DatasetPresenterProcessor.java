package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;

public class DatasetPresenterProcessor {

  private static final String nl = System.getProperty("line.separator");
  public static final String TEMPLATE_ANCHOR = "TEMPLATE_ANCHOR";

  // ////// static methods //////////////

  public static void processDatasetPresenterSet(
      DatasetPresenterSet datasetPresenterSet, String templatesFilePath,
      String project_home, String gus_home) {

    TemplateSet templateSet = new TemplateSet();
    templateSet.parseTemplatesFile(templatesFilePath);

    DatasetInjectorSet datasetInjectorSet = datasetPresenterSet.getDatasetInjectorSet();

    Set<String> anchorFileNameToTemplates = templateSet.getAnchorFileNames();

    Pattern patt = Pattern.compile(TEMPLATE_ANCHOR + "\\s+(\\w+)");
    for (String anchorFileName : anchorFileNameToTemplates) {
      Set<String> templateNamesExpectedInThisFile = templateSet.getTemplateNamesByAnchorFileName(anchorFileName);
      Set<String> templateNamesNotFound = new HashSet<String>(
          templateNamesExpectedInThisFile);

      String line;
      try {
        BufferedWriter bw = null;
        BufferedReader br = null;
      try {
        FileInputStream in = new FileInputStream(anchorFileName);
        br = new BufferedReader(new InputStreamReader(in));
        FileWriter fw = new FileWriter(anchorFileName);
        bw = new BufferedWriter(fw);
        while ((line = br.readLine()) != null) {
          bw.append(line + nl);
          Matcher m = patt.matcher(line);
          bw.write(line);
          bw.newLine();
          if (m.find()) {
            String templateNameInAnchor = m.group(1);
            if (!templateNamesExpectedInThisFile.contains(templateNameInAnchor)) {
              // throw exception
            }
            templateNamesNotFound.remove(templateNameInAnchor);
            Template template = templateSet.getTemplateByName(templateNameInAnchor);
            String textToInject = datasetInjectorSet.getTemplateInstancesAsText(template);
            bw.write(textToInject);
          }
        }
      } catch (FileNotFoundException ex) {
        throw new UserException("Can't find template anchors file "
            + anchorFileName);
      } catch (IOException ex) {
        throw new UserException("Can't write to template target file "
            + anchorFileName, ex);
      } finally {
        if (bw != null) bw.close();
        if (br != null) br.close();
      }
      } catch (IOException ex) {
        throw new UnexpectedException(ex);
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
    String project_home = System.getenv("PROJECT_HOME");
    String gus_home = System.getenv("GUS_HOME");
    TemplateSet templateSet = new TemplateSet();
    templateSet.parseTemplatesFile("lib/dst/rnaSeqTemplates.dst");
  }

}
