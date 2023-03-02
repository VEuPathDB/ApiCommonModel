package org.apidb.apicommon.model.datasetInjector;

import org.apidb.apicommon.model.datasetInjector.GeneList;

public class SubcellularGeneList extends  GeneList {

    public String searchCategory() {
        return("searchCategory-subcellular-gene-list");
    }
    public String questionName() {
        return("GenesBySubcellularGeneList" + getDatasetName());

    }
    public String questionTemplateName() {
        return("geneListSubcellular");
    }
}
