package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;

/**
 * Add one or more sets of DatasetPresenters into the presentation layer by
 * injecting their templates into target anchor files.
 * 
 * All DatasetPresenters for a model must be processed together. There is no
 * incremental adding of a DatasetPresenter to the model. All target anchor
 * files are cleaned and rewritten by this process. (The process does not clean
 * out target anchor files no longer reference by the template set.)
 * 
 * @author steve
 * 
 */
public class TemplatesInjector {

  private static final String nl = System.getProperty("line.separator");
  public static final String TEMPLATE_ANCHOR = "TEMPLATE_ANCHOR";
  private TemplateSet templateSet;
  private DatasetInjectorSet datasetInjectorSet;
  private List<DatasetPresenterSet> datasetPresenterSets = new ArrayList<DatasetPresenterSet>();

  public TemplatesInjector(DatasetPresenterSet datasetPresenterSet, TemplateSet templateSet) {
    this.datasetPresenterSets.add(datasetPresenterSet);
    this.templateSet = templateSet;
  }

  /**
   * Get a DatasetInjectorSet from all the datasetPresenterSets in
   * this.datasetPresenterSets.
   * 
   * Pass templatesFilesPath to this.templateSet so it can intitialize itself
   * (parse).
   * 
   * Get a list of anchor file names from the templateSet and iterate through
   * those. Scan each anchor file:
   * <ul>
   * <li>find each anchor in the file (pattern match)</li>
   * <li>use the template name in the anchor to get a Template from the
   * TemplateSet</li>
   * <li>use the Template to get its instances from the datasetInjectorSet</li>
   * <li>check that the template anchors found in the file agree with the
   * templates the set expects for that anchor file</li>
   * </ul>
   * 
   * @param templatesFilePath
   * @param project_home
   * @param gus_home
   */
  public void processDatasetPresenterSet(String templatesFilePath,
      String project_home, String gus_home) {

    initDatasetInjectorSet();

    Set<String> anchorFileNames = templateSet.getAnchorFileNames();

    Pattern patt = Pattern.compile(TEMPLATE_ANCHOR + "\\s+(\\w+)");
    for (String anchorFileName : anchorFileNames) {
      String targetFileName = Template.getTargetFileName(anchorFileName);
      String anchorFilePath = project_home + "/" + anchorFileName;
      String targetFilePath = gus_home + "/" + targetFileName;
      Set<String> templateNamesExpectedInThisFile = templateSet.getTemplateNamesByAnchorFileName(anchorFileName);
      Set<String> templateNamesNotFound = new HashSet<String>(
          templateNamesExpectedInThisFile);

      String line;
      try {
        BufferedWriter bw = null;
        BufferedReader br = null;
        try {
          FileInputStream in = new FileInputStream(anchorFilePath);
          br = new BufferedReader(new InputStreamReader(in));
          FileWriter fw = new FileWriter(targetFilePath);
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
              String textToInject = datasetInjectorSet.getTemplateInstanceSet().getTemplateInstancesAsText(
                  template);
              bw.write(textToInject);
            }
          }
        } catch (FileNotFoundException ex) {
          throw new UserException("Can't find template anchors file "
              + anchorFilePath, ex);
        } catch (IOException ex) {
          throw new UserException("Can't write to template target file "
              + targetFilePath, ex);
        } finally {
          if (bw != null)
            bw.close();
          if (br != null)
            br.close();
        }
      } catch (IOException ex) {
        throw new UnexpectedException(ex);
      }
    }
  }

  /**
   * Iterate across all DatasetPresenterSets and have them add their
   * DatasetInjectors to a DatasetInjectorSet
   */
  void initDatasetInjectorSet() {
    datasetInjectorSet = new DatasetInjectorSet();
    for (DatasetPresenterSet datasetPresenterSet : datasetPresenterSets) {
      datasetPresenterSet.addToDatasetInjectorSet(datasetInjectorSet);
    }

  }

  // ////// static methods //////////////

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
    TemplatesFileParser.parseTemplatesFile(templateSet,
        "lib/dst/rnaSeqTemplates.dst");
  }

}
