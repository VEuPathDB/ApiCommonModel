package org.apidb.apicommon.model.datasetInjector.custom.ToxoDB;

import org.apidb.apicommon.model.datasetInjector.RNASeqEbi;

public class RNASeqHehl extends RNASeqEbi {

  @Override
  public void injectTemplates() {
      setProfileSetParamQueryTemplate("rnaSeqProfileSetParamQueryHehlToxo");
      setPctProfileSetParamQueryTemplate("rnaSeqPctProfileSetParamQueryHehlToxo");
      setAntisenseSamplesParamQueryTemplate("antisenseSamplesParamQueryHehlToxo");
      // the shared sense/antisense query takes one sense strand for all samples,
      // but the two combined datasets have opposite strand switches
      setSenseAntisenseQuestionTemplate("rnaSeqSenseAntisenseQuestionHehlToxo");

      super.injectTemplates();

      injectTemplate("rnaSeqSenseAntisenseQueryHehlToxo");
  }


}
