package org.apidb.apicommon.datasetPresenter;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

import org.apidb.apicommon.model.datasetInjector.custom.AmoebaDB.MicroarrayGilchristAmoebapore;
import org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB.ChIPChip;
//import org.apidb.apicommon.model.datasetInjector.custom.PlasmoDB.PathwayGinsburg;
import org.gusdb.fgputil.xml.Text;

public class DiscoverableDatasetInjectorTest {

  public static void main(String[] args) {
    // pick test injectors
    DatasetInjector[] injectors = { new MicroarrayGilchristAmoebapore(),
        new ChIPChip() };//, new PathwayGinsburg() };

    // construct property values
    Map<String, String> propValues = new HashMap<>();
    Random random = new Random();
    for (DatasetInjector injector : injectors) {
      for (String[] decl : injector.getPropertiesDeclaration()) {
        propValues.put(decl[0], "value-" + random.nextInt());
      }
    }

    // construct DiscoverableDatasetInjector
    Contact contact = new Contact();
    contact.setName(new Text("Contact-" + random.nextInt()));
    DiscoverableDatasetInjector discoverer = new DiscoverableDatasetInjector();
    discoverer.setDatasetName("Dataset-" + random.nextInt());
    discoverer.setPrimaryContact(contact);
    discoverer.addPropValues(propValues);

    Collection<DatasetInjector> discovered = discoverer.getInjectors();
    for (DatasetInjector injector : injectors) {
      String name = injector.getClass().getName();
      boolean hasName = false;
      for (DatasetInjector disc : discovered) {
        String discName = disc.getClass().getName();
        if (discName.equals(name)) {
          hasName = true;
          break;
        }
      }
      if (!hasName)
        System.err.println("The DatasetInjector '" + name
            + "' failed to be discovered");
    }
    System.out.println("Totally discovered " + discovered.size() + " injectors.");
    for (DatasetInjector injector : discovered) {
      System.out.println(injector.getClass().getName());
    }
  }
}
