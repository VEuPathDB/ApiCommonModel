package org.apidb.apicommon.datasetPresenter;

public class Publication {
    private String pubmedId;
    private String citation;

    public void setPubmedId(String pubmedId) {
        this.pubmedId = pubmedId;
    }
    
    public String getPubmedId() {
        return pubmedId;
    }

    public String getCitation() {
        if (citation == null) {
            try {
                byte[] bo = new byte[100000];
                String[] cmd = { "pubmedIdToCitation", pubmedId };
                Process p = Runtime.getRuntime().exec(cmd);
                p.waitFor();
                p.getInputStream().read(bo);
                p.destroy();
                citation = new String(bo).trim();
            } catch (Exception e) {
                throw new UnexpectedException("Failed running: pubmedIdToCitation "
                                              + pubmedId, e);
            }
        }
        return citation;
    }

    @Override
    public String toString() {
        return("PMID: " + this.pubmedId + "\tCitation: " + this.citation);
    }


    
}
