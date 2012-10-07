package org.apidb.apicommon.datasetInjector;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

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

  /**
   * Add a DatasetPresenter to this set.
   * 
   * Called at Model construction
   */
  public void addDatasetPresenter(DatasetPresenter presenter) {
    presenters.add(presenter);
  }

  /**
   * Add DatasetInjector subclasses constructable by this set to a DatasetInjectorSet.  Traverse the tree to find all DatasetPresenters
   * and in turn their DatasetInjectorConstructors. The latter each construct a
   * DatasetInjector subclass which is added to the DatasetInjectorSet
   * 
   *  Called at processing time. 
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

}
