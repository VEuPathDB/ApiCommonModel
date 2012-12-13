package org.apidb.apicommon.datasetPresenter;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * A set of DatasetPresenters. A DatasetPresenterSet has one or more
 * DatasetPresenters. DatasetPresenters have one or more
 * DatasetInjectorConstructors. The whole tree is a model made of simple bean
 * objects created by parsing the XML users use to specify the model.
 * 
 * At processing time the tree is transformed into a DatasetInjectorSet.
 * 
 * @author steve
 * 
 */
public class DatasetPresenterSet {

  private List<DatasetPresenter> presenters = new ArrayList<DatasetPresenter>();
  private Set<String> presenterNames = new HashSet<String>();
  private List<InternalDataset> internalDatasets = new ArrayList<InternalDataset>();
  private Set<String> internalDatasetNames = new HashSet<String>();  
  private Set<String> namePatterns = new HashSet<String>();  

  /**
   * Add a DatasetPresenter to this set.
   * 
   * Called at Model construction
   */
  public void addDatasetPresenter(DatasetPresenter presenter) {
    String name = presenter.getDatasetName();
    if (presenterNames.contains(name))
      throw new UserException("DatasetPresenter already exists with name: "
          + name);
    if (internalDatasetNames.contains(name))
      throw new UserException("InternalDataset already exists with name: "
          + name);
    presenterNames.add(name);
    presenters.add(presenter);
    String pattern = presenter.getDatasetNamePattern();
    if (pattern != null) {
      if (namePatterns.contains(pattern))
        throw new UserException("datasetNamePattern already exists: "
            + pattern);
      namePatterns.add(pattern);
    }
  }

  public void addInternalDataset(InternalDataset internalDataset) {
    String name = internalDataset.getName();
    if (presenterNames.contains(name))
      throw new UserException("DatasetPresenter already exists with name: "
          + name);
    if (internalDatasetNames.contains(name))
      throw new UserException("InternalDataset already exists with name: "
          + name);
    internalDatasetNames.add(name);
    internalDatasets.add(internalDataset);

  }

  /**
   * Add the members of a DatasetPresenterSet to this set (during model
   * construction).
   */
  void addDatasetPresenterSet(DatasetPresenterSet datasetPresenterSet) {
    presenters.addAll(datasetPresenterSet.getDatasetPresenters());
  }

  /**
   * Add DatasetInjector subclasses constructable by this set to a
   * DatasetInjectorSet. Traverse the tree to find all DatasetPresenters and in
   * turn their DatasetInjectorConstructors. The latter each construct a
   * DatasetInjector subclass which is added to the DatasetInjectorSet
   * 
   * Called at processing time.
   */
  void addToDatasetInjectorSet(DatasetInjectorSet datasetInjectorSet) {
    for (DatasetPresenter presenter : presenters) {
      for (DatasetInjectorConstructor datasetInjectorConstructor : presenter.getDatasetInjectors()) {
        datasetInjectorSet.addDatasetInjector(datasetInjectorConstructor.getDatasetInjector());
      }
    }
  }

  int getSize() {
    return presenters.size();
  }

  List<DatasetPresenter> getDatasetPresenters() {
    return Collections.unmodifiableList(presenters);
  }
  
  List<InternalDataset> getInternalDatasets() {
    return Collections.unmodifiableList(internalDatasets);
  }


  void validateContactIds(String contactsFileName) {
    ContactsFileParser parser = new ContactsFileParser();
    String project_home = System.getenv("PROJECT_HOME");
    Contacts contacts = parser.parseFile(project_home
        + "/ApiCommonShared/DatasetPresenter/testData/contacts.xml.test");
    for (DatasetPresenter presenter : presenters) {
      presenter.getContacts(contacts);
    }
  }

  // //////////////////// Static methods //////////////////

  static DatasetPresenterSet createFromPresentersDir(String presentersDir) {
    File pres = new File(presentersDir);
    if (!pres.isDirectory())
      throw new UserException("Presenters dir " + presentersDir
          + " must be an existing directory");

    DatasetPresenterParser dpp = new DatasetPresenterParser();
    return dpp.parseDir(presentersDir);
  }

}
