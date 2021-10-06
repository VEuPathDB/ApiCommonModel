package org.apidb.apicommon.model.datasetInjector.custom.MicrosporidiaDB;

import org.apidb.apicommon.model.datasetInjector.RNASeqEbi;

public class RNASeqTroemelTimeCourse extends RNASeqEbi {

  @Override
  public void injectTemplates() {
      setProfileSetParamQueryTemplate("rnaSeqProfileSetParamQueryTroemelTC");

      super.injectTemplates();
  }


}
