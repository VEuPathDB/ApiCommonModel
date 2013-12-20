package org.apidb.apicommon.model.datasetInjector.custom.MicrosporidiaDB;

import org.apidb.apicommon.model.datasetInjector.CusomGenePageExpressionGraphs;

public class RNASeqTroemelElegansInfection extends CusomGenePageExpressionGraphs {

   @Override
   public void injectTemplates() {
 
       String projectName = getPropValue("projectName");
 
       String datasetName = getDatasetName();
 
       setOrganismAbbrevFromDatasetName();
       setOrganismAbbrevInternalFromDatasetName();
 
       injectTemplate("rnaSeqCoverageTrack");
       injectTemplate("rnaSeqJunctionsTrack");
   } 

  @Override
  public void addModelReferences() {
      addWdkReference("GeneRecordClasses.GeneRecordClass", "profile_graph", "Troemel::CelegansInfectionTimeSeries"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionFC"); 
      addWdkReference("GeneRecordClasses.GeneRecordClass", "question", "GeneQuestions.GenesByRNASeqTroemelCeInfectionPercentile"); 
  }
  
}
