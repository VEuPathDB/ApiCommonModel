package org.apidb.apicommon.model.report;

import java.util.ArrayList;
import java.util.List;

public class GenBankCdsFeature extends GenBankFeature {

    //private int codonStart;

    private String translTable;

    private List<String> ecNumbers;
    private List<String> notes;
    //private List<String> signalPeptides;
    //private List<String> transmembraneHelixes;

    public GenBankCdsFeature(GenBankFeature genbankFeature, String sequence, String translTable, int codonStart, String proteinId) {
        super(genbankFeature, "cds");

        this.setSequence(sequence);
        this.setProteinId(proteinId);

        this.translTable = translTable;
        //this.codonStart = codonStart;

        this.ecNumbers = new ArrayList<String>();
        this.notes = new ArrayList<String>();
        //this.signalPeptides = new ArrayList<String>();
        //this.transmembraneHelixes = new ArrayList<String>();
    }

    protected void addNote(String note) {
        if(note != null)
            this.notes.add(note);
    }

    protected void addEcNumber(String ecNumber) {
        if(ecNumber != null)
            this.ecNumbers.add(ecNumber);
    }

    protected String getTranslation() {
        return(super.getSequence());
    }

    @Override
    public String toString() {
        String rv = super.toString();

        String translation = this.getTranslation();

        rv = rv + "\t\t\ttransl_table\t" + this.translTable + "\n";

        rv = rv + "\t\t\ttranslation\t" + translation + "\n";

        for(String ec : this.ecNumbers) {
            rv = rv + "\t\t\tEC_number\t" + ec + "\n";
        }

        for(String note : this.notes) {
            rv = rv + "\t\t\tnote\t" + note + "\n";
        }


        return(rv);
    }

}


