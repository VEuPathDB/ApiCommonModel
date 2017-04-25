package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import java.util.List;

public class Origins extends  DatasetInjector {
  
  /*
   * getPropValues() gets the property values provided by the datasetPresenter
   * xml file. they are validated against the names provided in
   * getPropertyNames(). in the code below, the whole bundle is passed to each
   * of the templates even though a given template might not need all of them.
   * this is just convenience, rather than tailoring the list per template, it
   * is safe to pass all in, because unneeded ones will be ignored.
   */

  @Override
  public void injectTemplates() {

      setPropValue ("organismAbbrevDisplay", getOrganismAbbrevDisplayFromDatasetName());

      List<String> sampleNames = getSampleList();
      
      for (int i=0; i<sampleNames.size(); i++){
          if (sampleNames.get(i).endsWith("_ref")){
            String reference = sampleNames.get(i);
            for (int j=0; j<sampleNames.size(); j++) {
                if (sampleNames.get(j) != reference) {
                    String comparison = sampleNames.get(j);
                    setPropValue("reference", reference.replace("_ref", ""));
                    setPropValue("comparison", comparison);
                    setPropValue("fileName", reference + "_" + comparison + ".bw");
                    injectTemplate("originsDatabase");
                    injectTemplate("originsTrack");
                    setPropValue("gbrowseTrackName", getDatasetName() + getPropValue("reference") + comparison);
                    injectTemplate("gbrowseTrackCategory");
                }
            }
         }
      }

  }


  @Override
  public void addModelReferences() {
  }
  
  // declare properties required beyond those inherited from the datasetPresenter
  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String [][] declaration = {
       };

    return declaration;
  }
}
