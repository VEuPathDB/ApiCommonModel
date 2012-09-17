package org.apidb.apicommon.datasetInjector;

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
  
  //////// static methods //////////////
  
  private static Map<String, Template> parseTemplatesFile(String templatesFileName) {
    String templatesFilePath = GUS_HOME + "/" + templatesFileName;
    return new HashMap<String, Template>();
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
