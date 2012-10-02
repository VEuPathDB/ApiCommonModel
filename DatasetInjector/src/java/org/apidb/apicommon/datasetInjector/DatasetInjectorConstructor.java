package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.Map;

import org.gusdb.fgputil.xml.NamedValue;

/**
 * A constructor of a DatasetInjector. At model construction time, this object
 * is given the name of the injector class and its property values. At
 * processing time it is called to construct and initialize the injector.
 */

public class DatasetInjectorConstructor {
  final static String nl = System.getProperty("line.separator");

  private String datasetInjectorClassName;
  private Map<String, String> propValues = new HashMap<String, String>();
  private String datasetName;

  /*
   * Model construction methods
   */
  void setClass(String datasetInjectorClassName) {
    this.datasetInjectorClassName = datasetInjectorClassName;
  }

  void addProp(NamedValue propValue) {
    if (propValues.containsKey(propValue.getName())) {
      throw new UserException("A datasetInector in datasetPresenter '"
          + datasetName + "' has redundant property: " + propValue.getName());
    }
    propValues.put(propValue.getName(), propValue.getValue());
  }

  void inheritDatasetProps(DatasetPresenter datasetPresenter) {
    datasetName = datasetPresenter.getDatasetName();
    for (String key : datasetPresenter.getPropValues().keySet()) {
      if (propValues.containsKey(key))
        throw new UserException("In DatasetPresenter " + datasetName
            + " DatasetInjector for class " + "in dataset ");
      propValues.put(key, datasetPresenter.getPropValues().get(key));
    }
  }

  Map<String, String> getPropValues() {
    return propValues;
  }

  DatasetInjector getDatasetInjector() {
    DatasetInjector di = null;
    Class<? extends DatasetInjector> injectorClass = null;
    try {
      injectorClass = Class.forName(datasetInjectorClassName).asSubclass(
          DatasetInjector.class);
      di = injectorClass.newInstance();
    } catch (ClassNotFoundException | IllegalAccessException
        | InstantiationException ex) {
      throw new UserException(
          "Can't find DatasetInjector java class with name '"
              + datasetInjectorClassName + "'", ex);
    }

    di.addPropValues(propValues);
    di.setDatasetName(datasetName);
    return di;
  }
}
