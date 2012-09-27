package org.apidb.apicommon.datasetInjector;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.gusdb.fgputil.CliUtil;
import org.gusdb.fgputil.runtime.GusHome;

/*
 * A set of DatasetInjectors.   Can provide an associated set of templateName->propBundles
 */
public class DatasetInjectorSet {

  private static final String nl = System.getProperty("line.separator");
  private static final String GUS_HOME = GusHome.getGusHome();

  private Set<DatasetInjector> datasetInjectors;
  private Map<String, Set<Map<String, String>>> templateInstances = new HashMap<String, Set<Map<String, String>>>();

  // called during model construction
  public void addDatasetInjector(DatasetInjector datasetInjector) {
    datasetInjectors.add(datasetInjector);
    datasetInjector.setDatasetInjectorSet(this);
  }

  // called by processor
  public Map<String, Set<Map<String, String>>> getTemplateInstances() {
    for (DatasetInjector injector : datasetInjectors) {
      injector.injectTemplates();
    }
    return templateInstances;
  }

  // called by each injector, for each of its templates, when its injectTemplates() is called
  public void addTemplateInstance(String templateName,
      Map<String, String> propValues) {
    if (!templateInstances.containsKey(templateName)) {
      templateInstances.put(templateName, new HashSet<Map<String, String>>());
    }
    templateInstances.get(templateName).add(propValues);
  }

}
