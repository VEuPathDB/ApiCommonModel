package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;
import java.util.List;

public class CopyNumberVariations extends  DatasetInjector {
  
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

//Props from .prop for experiment
      String projectName = getPropValue("projectName");
      String organismAbbrev = getPropValue("organismAbbrev");
      String experimentName = getPropValue("experimentName");

      setPropValue ("organismAbbrevDisplay", getOrganismAbbrevDisplayFromDatasetName().replace(":", " "));

      
      String sampleNamePrefix = organismAbbrev + "_" + experimentName + "_";
      String sampleNameSuffix = "_copyNumberVariationSample_RSRC";
      List<String> sampleNames = getSampleList(sampleNamePrefix, sampleNameSuffix);
      
      for (int i=0; i<sampleNames.size(); i++){
          setPropValue("sampleName", sampleNames.get(i).replace("_CNV", ""));
          injectTemplate("copyNumberVariationsDatabase");
          injectTemplate("copyNumberVariationsTrack");
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
