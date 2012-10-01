package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.Map;

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
  private DatasetPresenter datasetPresenter;
  private String datasetInjectorInstanceClassName;

  /*
   * Model construction methods
   */
  void setClass(String datasetInjectorInstanceClassName) {

    this.datasetInjectorInstanceClassName = datasetInjectorInstanceClassName;
    Class<? extends DatasetInjectorInstance> injectorInstanceClass = null;
    try {
      injectorInstanceClass = Class.forName(datasetInjectorInstanceClassName).asSubclass(
          DatasetInjectorInstance.class);
      dii = injectorInstanceClass.newInstance();
      dii.setDatasetInjector(this);
    } catch (ClassNotFoundException | IllegalAccessException
        | InstantiationException ex) {
      throw new UserException(
          "Can't find DatasetInjectorInstance java class with name '"
              + datasetInjectorInstanceClassName + "'", ex);
    }
  }

  void addProp(NamedValue propValue) {
    if (propValues.containsKey(propValue.getName())) {
      throw new UserException("A datasetInector in datasetPresenter '"
          + datasetPresenter.getDatasetName() + "' has redundant property: "
          + propValue.getName());
    }
    propValues.put(propValue.getName(), propValue.getValue());
  }

  void inheritDatasetProps(DatasetPresenter datasetPresenter) {
    this.datasetPresenter = datasetPresenter;
    for (String key : datasetPresenter.getPropValues().keySet()) {
      if (propValues.containsKey(key))
        throw new UserException("In DatasetPresenter "
            + datasetPresenter.getDatasetName() + " DatasetInjector for class "
            + "in dataset ");
      propValues.put(key, datasetPresenter.getPropValues().get(key));
    }
  }

  void setDatasetInjectorSet(DatasetInjectorSet datasetInjectorSet) {
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

  DatasetInjectorInstance getDatasetInjectorInstance() {
    return dii;
  }

  /*
   * Facade methods
   */

  // instance injects multiple templates, calling back to the injectTemplate()
  // method
  // to do each one (see methods called by instance)
  public void injectTemplates() {
    String[][] propsDeclaration = dii.getPropertiesDeclaration();
    for (String[] decl : propsDeclaration) {
      if (!propValues.containsKey(decl[0])) {
        throw new UserException("A datasetInjector for class "
            + datasetInjectorInstanceClassName + " in DatasetPresenter "
            + datasetName + " is missing the required property " + decl[0]);
      }
    }
    dii.injectTemplates();
  }

  // instance inserts multiple references, calling back to this to do each one
  // (see methods called by instance)
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
