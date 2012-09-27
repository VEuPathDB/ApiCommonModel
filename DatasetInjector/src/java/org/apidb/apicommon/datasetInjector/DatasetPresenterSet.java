package org.apidb.apicommon.datasetInjector;

import java.util.HashSet;
import java.util.Set;

public class DatasetPresenterSet {
  
  Set<DatasetPresenter> presenters= new HashSet<DatasetPresenter>();
  
  public void addDatasetPresenter(DatasetPresenter presenter) {
    presenters.add(presenter);
  }
  
  public DatasetInjectorSet getDatasetInjectorSet() {
    DatasetInjectorSet datasetInjectorSet = new DatasetInjectorSet();
    for (DatasetPresenter presenter : presenters) {
      Set<DatasetInjector> datasetInjectors = presenter.getDatasetInjectors();
      for (DatasetInjector datasetInjector : datasetInjectors) {
        datasetInjectorSet.addDatasetInjector(datasetInjector);
      }
    }
    return datasetInjectorSet;
  }

}

