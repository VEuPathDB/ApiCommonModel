package org.apidb.apicommon.datasetInjector;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.gusdb.fgputil.xml.NamedValue;
import org.gusdb.fgputil.xml.Text;

/**
 * A specification for adding a dataset to the presentation layer. A simple data
 * holder that contains a set of properties and a set of
 * DatasetInjectorConstructors. At processing time it is transformed into a set
 * of DatasetInjector subclasses.
 * 
 * @author steve
 * 
 */
public class DatasetPresenter {

  Map<String, String> propValues = new HashMap<String, String>();

  private List<DatasetInjectorConstructor> datasetInjectors = new ArrayList<DatasetInjectorConstructor>();

  public void setDatasetName(String datasetName) {
    propValues.put("datasetName", datasetName);
  }

  public String getDatasetName() {
    return propValues.get("datasetName");
  }
  
  String getPropValue(String propName) {
    return propValues.get(propName);
  }

  public void setDatasetDescrip(Text datasetDescrip) {
    propValues.put("datasetDescrip", datasetDescrip.getText());
  }

  public void setDatasetDisplayName(String datasetDisplayName) {
    propValues.put("datasetDisplayName", datasetDisplayName);
  }

  public void setDatasetShortDisplayName(String datasetShortDisplayName) {
    propValues.put("datasetShortDisplayName", datasetShortDisplayName);
  }

  public void setProjectName(String projectName) {
    propValues.put("projectName", projectName);
  }

  public void setOrganismShortName(String organismShortName) {
    propValues.put("organismShortName", organismShortName);
  }

  public void setBuildNumberIntroduced(String buildNumberIntroduced) {
    propValues.put("buildNumberIntroduced", buildNumberIntroduced);
  }

  public void addDatasetInjector(DatasetInjectorConstructor datasetInjector) {
    datasetInjectors.add(datasetInjector);
    datasetInjector.inheritDatasetProps(this);
  }

  public List<DatasetInjectorConstructor> getDatasetInjectors() {
    return datasetInjectors;
  }

  public void addProp(NamedValue propValue) {
    if (propValues.containsKey(propValue.getName())) {
      throw new UserException("atasetPresenter '" + getDatasetName()
          + "' has redundant property: " + propValue.getName());
    }
    propValues.put(propValue.getName(), propValue.getValue());
  }

  public Map<String, String> getPropValues() {
    return propValues;
  }
}
