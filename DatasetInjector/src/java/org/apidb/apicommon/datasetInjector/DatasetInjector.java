package org.apidb.apicommon.datasetInjector;

import java.util.Properties;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;

public abstract class DatasetInjector {
  final static String nl = System.getProperty("line.separator");

    protected String datasetName;

    protected Properties getPropValues() { return null; }

    protected void injectWdkTemplate(String templateName, Properties propValues) {}

    protected void injectGbrowseTemplate(String templateName, Properties propValues) {}
    
    protected abstract void injectTemplates();
    
    protected abstract void insertReferences();
    
    protected abstract String[][] getPropertyNames();

    // discovers datasetName from propValues
    protected void makeWdkReference(String recordClass, String type, String name) {}
    
    private static Options declareOptions() {
      Options options = new Options();

      OptionGroup actions = new OptionGroup();
      Option template = new Option("t", "Inject templates");
      actions.addOption(template);

      Option ref = new Option("r", "Make references");
      actions.addOption(ref);

      options.addOptionGroup(actions);

      CliUtil.addOption(options, "presenterFiles", "one or more dataset presenter xml files", true, true);

      return options;
  }
    
    private static String getUsageNotes() {
      return

      nl
              + "";
    }

    public CommandLine getCmdLine(String[] args) {
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
    
    public void main(String[] args) throws Exception {

      CommandLine cmdLine = getCmdLine(args);
      
    }

}
 
