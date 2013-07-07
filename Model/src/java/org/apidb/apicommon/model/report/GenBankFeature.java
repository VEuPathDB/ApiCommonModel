package org.apidb.apicommon.model.report;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class GenBankFeature {

    protected static final String PARTIAL_START = "<";
    protected static final String PARTIAL_END = ">";

    private List<GenBankLocation> locations;

    private List<String> dbXrefs;

    private String locus;
    private String sequenceOntology;
    private String featureType;
    private String product;


    private String sequence;

    private boolean hasPartialStart;
    private boolean hasPartialEnd;

    private boolean isPseudo;


    public GenBankFeature(String locus, boolean isPseudo, String sequenceOntology, String featureType, String sequence, String product) {
        this.locus = locus;
        this.isPseudo = isPseudo;
        this.sequenceOntology = sequenceOntology;
        this.sequence = sequence;
        this.product = product;

        if(featureType.equals("gene") || featureType.equals("cds") || featureType.equals("exon")) {
            this.featureType = featureType;
        } else {
            this.featureType = "unknown";
        }

        this.dbXrefs = new ArrayList<String>();

        // partial start and end will be inherited by children
        this.hasPartialStart = hasPartialStart();
        this.hasPartialEnd = hasPartialEnd();
    }


    public GenBankFeature(GenBankFeature genbankFeature, String featureType) {
        this.locus = genbankFeature.locus;
        this.isPseudo = genbankFeature.isPseudo;
        this.sequenceOntology = genbankFeature.sequenceOntology;
        this.hasPartialStart = genbankFeature.hasPartialStart;
        this.hasPartialEnd = genbankFeature.hasPartialEnd;
        this.dbXrefs = genbankFeature.dbXrefs;
        this.sequence = genbankFeature.sequence;
        this.product = genbankFeature.product;

        this.featureType = featureType;
    }


    @Override
    public String toString() {
        String genbankFeatureKey;
        if(this.featureType.equals("cds")) {
            genbankFeatureKey = this.featureType.toUpperCase();
        } 
        else if(this.featureType.equals("exon")) {

            if(this.sequenceOntology.equals("protein coding")) {
                genbankFeatureKey = "mRNA";
            } else if(this.sequenceOntology.equals("rRNA encoding")) {
                genbankFeatureKey = "rRNA";
            } else if(this.sequenceOntology.equals("tRNA encoding")) {
                genbankFeatureKey = "tRNA";
            } else {
                genbankFeatureKey = "ncRNA";
            }
        }
        else {
            genbankFeatureKey = this.featureType;
        }

        String rv = locationsString(genbankFeatureKey);


        rv = rv + "\t\t\tlocus_tag\t" + this.locus + "\n";
        rv = rv + "\t\t\tproduct\t" + this.product + "\n";

        if(this.isPseudo) {
            rv = rv + "\t\t\tpseudo\t\n";
        }


        for(String dbXref : this.dbXrefs) {
            rv = rv + "\t\t\tdb_xref\t" + dbXref + "\n";
        }


        if(genbankFeatureKey.equals("ncRNA")) {
            String ncRnaClass = lookupRnaClass(this.sequenceOntology);
            rv = rv + "\t\t\tncRNA_class\t" + ncRnaClass + "\n";
        }

        //gene
        //gene_synonym

        return(rv);
    }

    private String lookupRnaClass(String s) {
        String rnaClass = "";

        if(s.equals("RNase MRP RNA"))
            rnaClass = "RNase_MRP_RNA";
        
        if(s.equals("RNase P RNA"))
            rnaClass = "RNase_P_RNA";
        if(s.equals("SRP RNA encoding"))
            rnaClass = "SRP_RNA";
        if(s.equals("scRNA encoding"))
            rnaClass = "scRNA";
        if(s.equals("snRNA encoding"))
            rnaClass = "snRNA";
        if(s.equals("snoRNA encoding"))
            rnaClass = "snoRNA";           
        if(s.equals("non protein coding"))
            rnaClass = "other";           
        if(s.equals("repeat region"))
            rnaClass = "other";           

        return(rnaClass);
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
                end = PARTIAL_START + end;
            }


            if(this.hasPartialEnd && strand.equals("forward") && count == this.locations.size() - 1) {
                end = PARTIAL_END + end;
            }


            if(this.hasPartialEnd && count == 0 && strand.equals("reverse")) {
                start = PARTIAL_END + start;
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
        List<GenBankLocation> myLocations = new ArrayList<GenBankLocation>();

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


    protected String getSequence() {
        return(this.sequence);
    }

    protected String getSequenceOntology() {
        return(this.sequenceOntology);
    }

    protected void setSequence(String sequence) {
        this.sequence = sequence;
    }

    protected boolean hasPartialStart() {

        if(this.sequence != null && this.sequenceOntology.equals("protein coding")) {
            if (!this.sequence.startsWith("ATG")) {
                return(true);
            }
        }
        return(false);
    }

    protected boolean hasPartialEnd() {

        if(this.sequence != null && this.sequenceOntology.equals("protein coding")) {

            if (!this.sequence.endsWith("TAG") && !this.sequence.endsWith("TAA")
                && !this.sequence.endsWith("TGA")) {
                return true;
            }
        }
        return false;
    }

}
