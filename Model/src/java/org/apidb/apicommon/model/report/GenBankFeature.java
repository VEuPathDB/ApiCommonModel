package org.apidb.apicommon.model.report;

import java.util.List;
import java.util.ArrayList;

import org.apidb.apicommon.model.report.GenBankLocation;

import java.util.Collections;

import java.io.PrintWriter;

public class GenBankFeature {

    protected static final String PARTIAL_START = "<";
    protected static final String PARTIAL_END = ">";

    private List<GenBankLocation> locations;

    private List<String> dbXrefs;

    private String locus;
    private String sequenceOntology;
    private String featureType;

    private String sequence;

    private boolean hasPartialStart;
    private boolean hasPartialEnd;

    private boolean seenPartialStart;
    private boolean seenPartialEnd;

    private boolean isPseudo;


    public GenBankFeature(String locus, boolean isPseudo, String sequenceOntology, String featureType, String sequence) {
        this.locus = locus;
        this.isPseudo = isPseudo;
        this.sequenceOntology = sequenceOntology;
        this.sequence = sequence;

        if(featureType.equals("gene") || featureType.equals("cds") || featureType.equals("exon")) {
            this.featureType = featureType;
        } else {
            this.featureType = "unknown";
        }

        this.dbXrefs = new ArrayList<String>();
    }


    public GenBankFeature(GenBankFeature genbankFeature, String featureType) {
        this.locus = genbankFeature.locus;
        this.isPseudo = genbankFeature.isPseudo;
        this.sequenceOntology = genbankFeature.sequenceOntology;
        this.hasPartialStart = genbankFeature.hasPartialStart;
        this.hasPartialEnd = genbankFeature.hasPartialEnd;
        this.dbXrefs = genbankFeature.dbXrefs;

        this.featureType = featureType;
    }


    public String toString() {
        String genbankFeatureKey;
        if(this.featureType.equals("cds")) {
            genbankFeatureKey = this.featureType.toUpperCase();
        } 
        else if(this.featureType.equals("exon")) {
            genbankFeatureKey = "mRNA";
        }
        else {
            genbankFeatureKey = this.featureType;
        }

        String rv = locationsString(genbankFeatureKey);


        rv = rv + "\t\t\tlocus_tag\t" + this.locus + "\n";

        if(this.isPseudo) {
            rv = rv + "\t\t\tpseudo\t\n";
        }


        for(String dbXref : this.dbXrefs) {
            rv = rv + "\t\t\tdb_xref\t\"" + dbXref + "\"\n";
        }

        //gene
        //gene_synonym

        //dbxref

        return(rv);
    }

    protected String locationsString(String featureKey) {

        String featureStrand = this.locations.get(0).getStrand();
        if(featureStrand.equals("reverse")) {
            Collections.reverse(this.locations);
        }

        int count = 0;

        String rv = "";

        for(GenBankLocation location : this.locations) {
            String start = location.getStart();
            String end = location.getEnd();
            String strand = location.getStrand();

            assert(strand.equals(featureStrand));

            if(this.hasPartialStart && strand.equals("forward") && count == 0) {
                start = PARTIAL_START + start;
            }

            if(this.hasPartialStart && strand.equals("reverse") && count == this.locations.size() - 1) {
                start = PARTIAL_START + start;
            }

            if(this.hasPartialStart && strand.equals("forward") && count == this.locations.size() - 1) {
                end = PARTIAL_END + end;
            }

            if(this.hasPartialStart && count == 0 && strand.equals("reverse")) {
                end = PARTIAL_END + end;
            }

            if(strand.equals("forward")) {
                rv = rv + start + "\t" + end + "\t";
            }
            else {
                rv = rv + end + "\t" + start + "\t";
            }

            if(count ==0) {
                rv = rv + featureKey + "\t\t\n";
            }
            else {
                rv = rv + "\t\t\t\n";
            }
            count++;
        }
        return(rv);
    }

    protected void setLocations(List<GenBankLocation> locations) {
        List<GenBankLocation> myLocations = new ArrayList();

        for (GenBankLocation location : locations) {
            String locationType = location.getType();

            if(this.featureType.equals(locationType)) {
                myLocations.add(location);
            }
        }
        this.locations = myLocations;
    }

    protected void addDbXref(String value) {
        if(!this.dbXrefs.contains(value) && value != null) {
            this.dbXrefs.add(value);
        }
    }

    protected boolean getIsPseudo() {
        return(this.isPseudo);
    }

    protected String getLocus() {
        return(this.locus);
    }

    protected String getSequenceOntology() {
        return(this.sequenceOntology);
    }

    protected boolean hasPartialStart() {
        if(this.seenPartialStart) {
            return(this.hasPartialStart);
        }

        String tmpSequence = this.sequence;
        if (tmpSequence != null) {
            tmpSequence = tmpSequence.substring(0, tmpSequence.length()
                                          - (tmpSequence.length() % 3));
            if (!tmpSequence.startsWith("ATG")) {
                this.hasPartialStart = true;
            }
        }

        this.seenPartialStart = true;

        return(this.hasPartialStart);
    }

    protected boolean hasPartialEnd() {
        if(this.seenPartialEnd) {
            return(this.hasPartialEnd);
        }

        String tmpSequence = this.sequence;
        if (tmpSequence != null) {
            tmpSequence = tmpSequence.substring(0, tmpSequence.length()
                                          - (tmpSequence.length() % 3));

            if (!sequence.endsWith("TAG") && !sequence.endsWith("TAA")
                && !sequence.endsWith("TGA")
                || sequence.length() % 3 != 0) {
                this.hasPartialEnd = true;
            }
        }

        this.seenPartialEnd = true;

        return(this.hasPartialEnd);
    }


    protected void setSequence(String sequence) {
        this.sequence = sequence;
    }


}
