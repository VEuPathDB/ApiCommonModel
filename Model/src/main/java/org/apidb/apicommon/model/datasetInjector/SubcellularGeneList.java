package org.apidb.apicommon.model.datasetInjector;

public class SubcellularGeneList extends  GeneList {

    @Override
    public String searchCategory() {
        return("searchCategory-subcellular-gene-list");
    }
    @Override
    public String questionName() {
        return("GenesBySubcellularGeneList" + getDatasetName());

    }
    @Override
    public String questionTemplateName() {
        return("geneListSubcellular");
    }
}
