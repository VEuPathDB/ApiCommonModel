package org.apidb.apicommon.datasetPresenter;

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

  // use prop values for properties that might be injected into templates.
  Map<String, String> propValues = new HashMap<String, String>();

  // use instance variables for properties that have no chance of being
  // injected.
  private String displayCategory;
  private String protocol;
  private String acknowledgement;
  private String caveat;
  private String releasePolicy;
  private DatasetInjector datasetInjector;

  private List<DatasetInjectorConstructor> datasetInjectorConstructors = new ArrayList<DatasetInjectorConstructor>();
  private List<String> contactIds = new ArrayList<String>(); // includes primary
  private String primaryContactId;
  private List<Contact> contacts;
  private List<Publication> publications = new ArrayList<Publication>();
  private List<HyperLink> links = new ArrayList<HyperLink>();

  public void setName(String datasetName) {
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

  public void setDatasetDisplayName(Text datasetDisplayName) {
    propValues.put("datasetDisplayName", datasetDisplayName.getText());
  }

  public void setDatasetShortDisplayName(Text datasetShortDisplayName) {
    propValues.put("datasetShortDisplayName", datasetShortDisplayName.getText());
  }

  public void setSummary(Text summary) {
    propValues.put("summary", summary.getText());
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

  public void setDisplayCategory(Text displayCategory) {
    this.displayCategory = displayCategory.getText();
  }

  public String getDisplayCategory() {
    return displayCategory;
  }

  public void setCaveat(Text caveat) {
    this.caveat = caveat.getText();
  }

  public String getCaveat() {
    return caveat;
  }

  public void setReleasePolicy(Text releasePolicy) {
    this.releasePolicy = releasePolicy.getText();
  }

  public String getReleasePolicy() {
    return releasePolicy;
  }

  public void setProtocol(Text protocol) {
    this.protocol = protocol.getText();
  }

  public String getProtocol() {
    return protocol;
  }

  public void setAcknowledgement(Text acknowledgement) {
    this.acknowledgement = acknowledgement.getText();
  }

  public String getAcknowledgement() {
    return acknowledgement;
  }

  public void addContactId(Text contactId) {
    contactIds.add(contactId.getText());
  }
  
  public void setPrimaryContactId(Text contactId) {
    primaryContactId = contactId.getText();
    contactIds.add(contactId.getText());
  }

  public List<String> getContactIds() {
    return contactIds;
  }

  public List<Contact> getContacts(Contacts allContacts) {
    if (contacts == null) {
      contacts = new ArrayList<Contact>();
      for (String contactId : contactIds) {
        Contact contact = allContacts.get(contactId);
        if (contact == null) {
          String datasetName = propValues.get("datasetName");
          throw new UserException("Dataset name " + datasetName
              + " has a contactId " + contactId
              + " that has no corresponding contact in contacts file "
              + allContacts.getContactsFileName());
        }
        contacts.add(contact);
        if (contactId.equals(primaryContactId)) contact.setIsPrimary(true);
      }
    }
    return contacts;
  }

  public void addPublication(Publication publication) {
    publications.add(publication);
  }

  public List<Publication> getPublications() {
    return publications;
  }

  public void addLink(HyperLink link) {
    links.add(link);
  }

  public List<HyperLink> getLinks() {
    return links;
  }

  /**
   * Add a DatasetInjector. This method should be changed to setDatasetInjector
   * as we no longer support multiple DasasetInjectors per DatasetPresenter
   * 
   * @param datasetInjector
   */
  public void addDatasetInjector(DatasetInjectorConstructor datasetInjector) {
    datasetInjectorConstructors.add(datasetInjector);
    datasetInjector.inheritDatasetProps(this);
  }

  private DatasetInjector getDatasetInjector() {
    if (datasetInjector == null) {
      DatasetInjectorConstructor dic = datasetInjectorConstructors.get(0);
      if (dic != null) {
        datasetInjector = dic.getDatasetInjector();
        datasetInjector.addModelReferences();
      }
    }
    return datasetInjector;
  }

  public List<ModelReference> getModelReferences() {
    List<ModelReference> answer = new ArrayList<ModelReference>();
    DatasetInjector di = getDatasetInjector();
    if (di != null) {
      answer = di.getModelReferences();
    }
    return answer;
  }

  public List<DatasetInjectorConstructor> getDatasetInjectors() {
    return datasetInjectorConstructors;
  }

  public void addProp(NamedValue propValue) {
    if (propValues.containsKey(propValue.getName())) {
      throw new UserException("datasetPresenter '" + getDatasetName()
          + "' has redundant property: " + propValue.getName());
    }
    propValues.put(propValue.getName(), propValue.getValue());
  }

  public Map<String, String> getPropValues() {
    return propValues;
  }
}
