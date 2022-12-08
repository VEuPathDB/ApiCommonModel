package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.RNASeqEbi;

public class RNASeqHehl extends RNASeqEbi {

  @Override
  public void injectTemplates() {
      setProfileSetParamQueryTemplate("rnaSeqProfileSetParamQueryHehlToxo");
      setPctProfileSetParamQueryTemplate("rnaSeqPctProfileSetParamQueryHehlToxo");
      setAntisenseSamplesParamQueryTemplate("antisenseSamplesParamQueryHehlToxo");

      super.injectTemplates();
  }


}
