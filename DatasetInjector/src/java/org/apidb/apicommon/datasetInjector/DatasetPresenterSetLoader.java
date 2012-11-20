package org.apidb.apicommon.datasetInjector;

import java.util.Map;

public class DatasetPresenterSetLoader {
  
  public DatasetPresenterSetLoader(String propFileName) {
    
  }
  
  // read contacts file and create contacts.
  void loadDatasetPresenterSet(DatasetPresenterSet dps, String contactsFileName) {
    Map<String, Contact> contacts = ContactsFileParser.parseContactsFile(contactsFileName);
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
