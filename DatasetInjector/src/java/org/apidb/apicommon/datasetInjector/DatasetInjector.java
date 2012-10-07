package org.apidb.apicommon.datasetInjector;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * An abstract superclass of DatasetInjectors. Contains the information needed
 * to inject a dataset into the presentation layer. That information is: a
 * bundle of property values and a set of templates (that require those
 * properties). A tuple (propertyValues, template) is called a
 * "template instance." This injector supplies one or more such tuples to the
 * containing DatasetInjectorSet.
 * 
 * @author steve
 * 
 */
public abstract class DatasetInjector {

  private Map<String, String> propValues = new HashMap<String, String>();
  private String datasetName;
  private DatasetInjectorSet datasetInjectorSet;

  /**
   * Subclasses use this method to declare the properties they require. These
   * properties must be the union of all the properties required by the
   * templates the subclass injects. Standard properties supplied by the
   * containing <code>DatasetPresenter</code> (e.g. "datasetName") must be
   * declared if they are required by any of the templates.
   * 
   * The values for these properties are supplied in three ways:
   * <ul>
   * <li>Standard properties required by a DatasetPresenter are inherited. These
   * are supplied by the user in the <datasetPresenter> element in the dataset
   * presenter XML file.
   * <li>
   * 
   * @see DatasetPresenter
   * @return an array of String pairs: (property name, documentation for that
   *         property)
   */
  protected abstract String[][] getPropertiesDeclaration();

  /**
   * Insert WDK references into the presentation layer. (Not implemented yet)
   */
  protected abstract void insertReferences();

  /**
   * Subclasses call this method to inject template instances into the
   * presentation layer. To do so they add a call in this method to
   * {@link #injectTemplate(String)}. The template will have available all
   * properties declared by <code>getPropertiesDeclaration</code>.
   * 
   * Optionally they provide additional hard-coded properties to templates by calling
   * {@link #setPropValue(String, String)} before calling
   * <code>injectTemplate()</code>.
   */
  protected abstract void injectTemplates();

  /**
   * Hard-code a property value to be passed to a template. Typically properties
   * are specified by the user in the datasetPresenter XML file. This will be
   * made available
   * 
   * @param key
   * @param value
   */
  protected void setPropValue(String key, String value) {
    propValues.put(key, value);
  }

  protected String getDatasetName() {
    return datasetName;
  }

  /**
   * Subclasses should call this method inside {@link #injectTemplates()} to
   * inject a template. The template will be passed all this injector's property
   * values. Optionally provide additional hard-coded property values by calling
   * addPropValue().
   */
  protected void injectTemplate(String templateName) {
    TemplateInstance templateInstance = new TemplateInstance(templateName,
        Collections.unmodifiableMap(propValues));
    datasetInjectorSet.injectTemplateInstance(templateInstance);
  }

  /**
   * Subclasses should call this method inside {@link #injectTemplates()} to
   * make a WDK reference. (Not implemented yet).
   * 
   * @param recordClass
   * @param type
   * @param name
   */
  protected void makeWdkReference(String recordClass, String type, String name) {}

  /**
   * Add property values.
   * @param propValues
   */
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

  /**
   * Set the name of the dataset that is being injected.
   * @param datasetName
   */
  void setDatasetName(String datasetName) {
    this.datasetName = datasetName;
  }

  /**
   * Set the parent DatasetInjectorSet.
   * @param datasetInjectorSet
   */
  void setDatasetInjectorSet(DatasetInjectorSet datasetInjectorSet) {
    this.datasetInjectorSet = datasetInjectorSet;
  }

}
