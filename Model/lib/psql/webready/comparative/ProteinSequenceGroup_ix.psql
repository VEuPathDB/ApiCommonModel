        create unique index PSG_idx ON :SCHEMA.ProteinSequenceGroup (full_id, group_name, taxon_id, source_id)
;

        create unique index PSG_gusIdx ON :SCHEMA.ProteinSequenceGroup (ortholog_group_id, aa_sequence_id)
;

        create unique index PSG_idx2 ON :SCHEMA.ProteinSequenceGroup (group_name, length desc, full_id, taxon_id)
;

         create unique index PSG_idx3
          on :SCHEMA.ProteinSequenceGroup (aa_sequence_id, group_name, ortholog_group_id, orthomcl_taxon_id, taxon_id)
 ;

        create unique index PSG_idx4 ON :SCHEMA.ProteinSequenceGroup (source_id, full_id, group_name, taxon_id)
;
