package org.apidb.apicommon.model.report;

import org.apidb.apicommon.model.report.GenBankFeature;

import java.util.List;
import java.util.ArrayList;

public class GenBankCdsFeature extends GenBankFeature {

    private int codonStart;

    private String translTable;
    private String product;

    private List<String> ecNumbers;
    private List<String> notes;

    public GenBankCdsFeature(GenBankFeature genbankFeature, String sequence, String translTable, int codonStart, String product) {
        super(genbankFeature.getLocus(), genbankFeature.getIsPseudo(), genbankFeature.getSequenceOntology(), "cds", sequence);

        this.translTable = translTable;
        this.codonStart = codonStart;
        this.product = product;

        this.ecNumbers = new ArrayList<String>();
        this.notes = new ArrayList<String>();;
    }

    protected String getTranslTable() {
        return(this.translTable);
    }

    protected int getCodonStart() {
        return(this.codonStart);
    }

    protected String getProduct() {
        return(this.product);
    }

    protected List getNotes() {
        return(this.notes);
    }

    protected void addNote(String note) {
        if(note != null)
            this.notes.add(note);
    }

    protected void addEcNumber(String ecNumber) {
        if(ecNumber != null)
            this.ecNumbers.add(ecNumber);
    }

    public String toString() {
        String rv = super.toString();
        rv = rv + "\t\t\tproduct\t" + this.product + "\n";
        rv = rv + "\t\t\ttransl_table\t" + this.translTable + "\n";

        for(String ec : this.ecNumbers) {
            rv = rv + "\t\t\tEc_number\t" + ec + "\n";
        }

        for(String note : this.notes) {
            rv = rv + "\t\t\tnote\t" + note + "\n";
        }


        return(rv);
    }

}


