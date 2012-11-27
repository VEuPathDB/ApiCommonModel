package org.apidb.apicommon.datasetInjector;


public class DatasetPresenterSetLoader {
  
  Contacts contacts;
  
  
  public DatasetPresenterSetLoader(String propFileName, String contactsFileName) {
    ConfigurationParser configParser = new ConfigurationParser();
    Configuration config = configParser.parseFile(propFileName);
    ContactsFileParser contactsParser = new ContactsFileParser();
    contacts = contactsParser.parseFile(contactsFileName);   
  }
  
  // read contacts file and create contacts.
  void loadDatasetPresenterSet(DatasetPresenterSet dps, String contactsFileName) {

    for(DatasetPresenter datasetPresenter : dps.getDatasetPresenters()) {
       int datasetPresenterId = loadDatasetPresenter(datasetPresenter);
       for (String contactId : datasetPresenter.getContactIds()) {
         Contact contact = contacts.get(contactId);
         loadContact(datasetPresenterId, contact);
       }
    } 
  }
  
  private int loadDatasetPresenter(DatasetPresenter datasetPresenter) {
    int datasetPresenterId =0;
    return datasetPresenterId;
  }
  
  private void loadContact(int datasetPresenterId, Contact contact) {
    
  }
  
  private void loadPublication(int datasetPresenterId, Publication publication) {
    
  }
  
}
