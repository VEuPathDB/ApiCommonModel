package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.Map;

public abstract class DatasetInjector {
  
  private Map<String, String> propValues = new HashMap<String, String>(); 
  private String datasetName;
  private DatasetInjectorSet datasetInjectorSet;

  public abstract String[][] getPropertiesDeclaration();

  public abstract void insertReferences();

  public abstract void injectTemplates();
  
  void addPropValues(Map<String, String> propValues) {
    this.propValues.putAll(propValues);
    
    // validate against declaration
    String[][] propsDeclaration = getPropertiesDeclaration();
    for (String[] decl : propsDeclaration) {
      if (!propValues.containsKey(decl[0])) {
        throw new UserException("A datasetInjector for class "
            + this.getClass().getName() + " in DatasetPresenter " + datasetName
            + " is missing the required property " + decl[0]);
      }
    }
  }
  
  protected void setPropValue(String key, String value) {
    propValues.put(key, value);
  }
  
  void setDatasetName(String datasetName) {
    this.datasetName = datasetName;
  }
  
  void setDatasetInjectorSet(DatasetInjectorSet datasetInjectorSet) {
    this.datasetInjectorSet = datasetInjectorSet;
  }

  protected Map<String, String> getPropValues() {
    return propValues;
  }
  
  protected String getDatasetName() {
    return datasetName;
  }
  
  /*
   * Methods called by subclass
   */
  public void injectTemplate(String templateName) {
    datasetInjectorSet.addTemplateInstance(templateName, propValues);
  }

  // discovers datasetName from propValues
  public void makeWdkReference(String recordClass, String type, String name) {}

}
