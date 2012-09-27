package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.gusdb.fgputil.xml.NamedValue;

/*
 * Facade for DatasetInjectorInstances.  A DatasetPresenter will have zero, one or more DatasetInjectors.
 * The DatasetInjector
 */

public class DatasetInjector {
  final static String nl = System.getProperty("line.separator");

  private DatasetInjectorInstance dii;
  private DatasetInjectorSet datasetInjectorSet;
  private Map<String, String> propValues = new HashMap<String, String>();
  private String datasetName;

  /*
   * Model construction methods
   */
  public void setClass(String datasetInjectorInstanceClassName) {
    Class<? extends DatasetInjectorInstance> injectorInstanceClass = null;
    try {
      injectorInstanceClass = Class.forName(datasetInjectorInstanceClassName).asSubclass(
          DatasetInjectorInstance.class);
      dii = injectorInstanceClass.newInstance();
    } catch (ClassNotFoundException | IllegalAccessException
        | InstantiationException ex) {
      throw new UserException(
          "Can't find DatasetInjectorInstance java class with name '"
              + datasetInjectorInstanceClassName + "'");
    }
  }

  public void addProp(NamedValue propValue) {
    propValues.put(propValue.getName(), propValue.getValue());
  }

  public void inheritDatasetProps(DatasetPresenter dataset) {
    for (String key : dataset.getPropValues().keySet()) {
      if (propValues.containsKey(key))
        throw new UserException("In DatasetPresenter "
            + dataset.getDatasetName() + " DatasetInjector for class "
            + "in dataset ");
      propValues.put(key, dataset.getPropValues().get(key));
    }
  }
  
  public void setDatasetInjectorSet(DatasetInjectorSet datasetInjectorSet) {
    this.datasetInjectorSet = datasetInjectorSet;
  }

  /*
   * Getters
   */
  public Map<String, String> getPropValues() {
    return propValues;
  }

  public String getDatasetName() {
    return datasetName;
  }

  /*
   * Facade methods
   */
  public String[][] getPropertiesDeclaration() {
    return dii.getPropertiesDeclaration();
  }

  // instance injects multiple templates, calling back to this to do each one (see methods called by instance)
  public void injectTemplates() {
    dii.injectTemplates();
  }
  
  // instance inserts multiple references, calling back to this to do each one (see methods called by instance)
  public void insertReferences() {
    dii.insertReferences();
  }

  /*
   * Methods called by instance class
   */
  public void injectTemplate(String templateName, Map<String, String> propValues) {
    datasetInjectorSet.addTemplateInstance(templateName, propValues);
  }

  // discovers datasetName from propValues
  public void makeWdkReference(String recordClass, String type, String name) {}
  
}
