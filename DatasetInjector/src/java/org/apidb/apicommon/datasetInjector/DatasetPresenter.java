package org.apidb.apicommon.datasetInjector;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.gusdb.fgputil.xml.Name;
import org.gusdb.fgputil.xml.NamedValue;

public class DatasetPresenter {
  
  Map<String, String> propValues = new HashMap<String, String>();
  private String datasetName;
  private String datasetDisplayName;
  private String datasetShortDisplayName;
  private String datasetDescrip;
  private String projectName;
  private String organismShortName;
  private Set<DatasetInjector> datasetInjectors;
  
  public void setDatasetName(String datasetName) {
    this.datasetName = datasetName;
  }
  
  public String getDatasetName() {
    return datasetName;
  }
  
  public void setDatasetDescrip(String datasetDescrip) {
    this.datasetDescrip = datasetDescrip;
  }
  
  public void setDatasetDisplayName(String datasetDisplayName) {
    this.datasetDisplayName = datasetDisplayName;
  }
  
  public void setDatasetShortDisplayName(String datasetShortDisplayName) {
    this.datasetShortDisplayName = datasetShortDisplayName;
  }
  
  public void setProjectName(String projectName) {
    this.projectName = projectName;
  }
  
  public void setOrganismShortName(String organismShortName) {
    this.organismShortName = organismShortName;
  }
  
  public void addDatasetInjector(DatasetInjector datasetInjector) {
    datasetInjectors.add(datasetInjector);
    datasetInjector.inheritDatasetProps(this);
  }
  
  public Set<DatasetInjector> getDatasetInjectors() {
    return datasetInjectors;
  }
  
  public void addProp(NamedValue propValue) {
    propValues.put(propValue.getName(), propValue.getValue());
  }
  
  public Map<String, String> getPropValues() {
    return propValues;
  }
}
