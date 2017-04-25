package org.apidb.apicommon.model.report;

public class GenBankLocation {

    // start and end strings because of partial locations
    private String start;
    private String end;
    private String strand;
    private String type;

    public GenBankLocation(String start, String end, String strand, String type) {
        this.start = start;
        this.end = end;
        this.strand = strand;
        this.type = type;
    }


    protected String getStart() {
        return(this.start);
    }

    protected String getEnd() {
        return(this.end);
    }

    protected String getStrand() {
        return(this.strand);
    }

    protected String getType() {
        return(this.type);
    }
}

