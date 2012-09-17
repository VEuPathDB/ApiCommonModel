package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;


import org.gusdb.fgputil.xml.NamedValue;

public  class DatasetInjector {
  final static String nl = System.getProperty("line.separator");
  
  DatasetInjectorInstance dii;

  protected Map<String, String> propertyValues = new HashMap<String, String>();

  protected String datasetName;

  public Properties getPropValues() {
    return null;
  }
  
  public String getDatasetName() {
    return datasetName;
  }
  
  public void setInstance() {

  }
  
  public void injectWdkTemplate(String templateName, Properties propValues) {}

  public void injectGbrowseTemplate(String templateName,
      Properties propValues) {}
  
  // discovers datasetName from propValues
  public void makeWdkReference(String recordClass, String type, String name) {}

  public String[][] getPropertiesDeclaration() {
    return dii.getPropertiesDeclaration();
  }
  
  public void insertReferences() {
    dii.insertReferences();
  }
  
  public void injectTemplates() {
    dii.injectTemplates();
  }
  
  public void addPropertyValue(NamedValue propValue) {
    propertyValues.put(propValue.getName(), propValue.getValue());
  }


}
