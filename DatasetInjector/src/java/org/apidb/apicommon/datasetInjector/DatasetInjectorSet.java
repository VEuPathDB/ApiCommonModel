package org.apidb.apicommon.datasetInjector;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.List;

/*
 * A set of DatasetInjectors.   Can provide an associated set of templateName->propBundles
 */
public class DatasetInjectorSet {

  private List<DatasetInjector> datasetInjectors = new ArrayList<DatasetInjector>();
  private Map<String, List<Map<String, String>>> allTemplateInstances = null;

  /*
   * Model construction
   */
  void addDatasetInjector(DatasetInjector datasetInjector) {
    datasetInjectors.add(datasetInjector);
    datasetInjector.setDatasetInjectorSet(this);
  }

  /*
   * Called at processing time
   */
  String getTemplateInstancesAsText(Template template) {
    return template.getInstancesAsText(allTemplateInstances.get(template.getName()));
  }

  List<Map<String, String>> getTemplateInstances(String templateName) {
    if (allTemplateInstances == null) {
      allTemplateInstances = new HashMap<String, List<Map<String, String>>>();

      // injectors call back to addTemplateInstance()
      for (DatasetInjector injector : datasetInjectors) {
        injector.injectTemplates();
      }
    }

    return allTemplateInstances.get(templateName);
  }

  // called by each injector, for each of its templates, when its
  // injectTemplates() is called
  void addTemplateInstance(String templateName, Map<String, String> propValues) {
    if (!allTemplateInstances.containsKey(templateName)) {
      allTemplateInstances.put(templateName, new ArrayList<Map<String, String>>());
    }
    allTemplateInstances.get(templateName).add(propValues);

  }

}
