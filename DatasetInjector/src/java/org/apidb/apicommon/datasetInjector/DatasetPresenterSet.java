package org.apidb.apicommon.datasetInjector;

import java.util.ArrayList;
import java.util.List;



public class DatasetPresenterSet {
  
  List<DatasetPresenter> presenters= new ArrayList<DatasetPresenter>();
  
  /*
   * Called at Model construction
   */
   void addDatasetPresenter(DatasetPresenter presenter) {
    presenters.add(presenter);
  }
  
   /*
    * Called at processing time.
    * Each datasetPresenter in this DatasetInjectorSet might have more than
    *  one injector.  gather all the injectors into a DatasetInjectorSet
    */
   DatasetInjectorSet getDatasetInjectorSet() {
    DatasetInjectorSet datasetInjectorSet = new DatasetInjectorSet();
    for (DatasetPresenter presenter : presenters) {
      List<DatasetInjector> datasetInjectors = presenter.getDatasetInjectors();
      for (DatasetInjector datasetInjector : datasetInjectors) {
        datasetInjectorSet.addDatasetInjector(datasetInjector);
      }
    }
    return datasetInjectorSet;
  }

}

