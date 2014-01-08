package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.datasetPresenter.DatasetInjector;

public class ProteinExpressionMassSpec extends DatasetInjector {

  @Override
  public void injectTemplates() {
      setShortAttribution();

      setOrganismAbbrevFromDatasetName();
      String datasetName = getDatasetName();
      String optionalOrganismAbbrev  = getPropValue("optionalOrganismAbbrev");
      if (!optionalOrganismAbbrev.equals("")) {
              setPropValue("organismAbbrev",optionalOrganismAbbrev);
          }
     
      String datasetNamePattern  = getPropValue("datasetNamePattern");
      if (datasetNamePattern == null || datasetNamePattern.equals("")) {
              setPropValue("edNameParamValue",datasetName);
      }
      else {
          setPropValue("edNameParamValue",datasetNamePattern);
      }
      injectTemplate("proteinExpressionMassSpecGBrowseTrack");


      if(getPropValueAsBoolean("isPhosphoProteomics")) {
          injectTemplate("proteinExpressionMassSpecPhosphoPBrowseTrack");
      }
      else {
          injectTemplate("proteinExpressionMassSpecPBrowseTrack");      
      }      
  }

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByMassSpec");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecMod");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpecDownload");
      addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "MassSpec");
  }

  // second column is for documentation
  @Override
  public String[][] getPropertiesDeclaration() {
      String[][] propertiesDeclaration = {{"species", "metadata for the sample organism, not the aligned organism"},
                                          {"optionalOrganismAbbrev","for cases when sample organism is different from the aligned organism"},
                                          {"isPhosphoProteomics","boolean to flag phosphoProteomics experiments for PBrowse"},
      };
      return propertiesDeclaration;
  }

}
