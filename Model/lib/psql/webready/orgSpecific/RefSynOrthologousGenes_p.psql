DROP TABLE IF EXISTS :SCHEMA.:CLEAN_ORG_ABBREVRefSynOrthologousGenesTmp;


/* ATTENTION: This table is empty. We will populate it in the comparative graph
We are creating it here so that it is partitioned and exists early in the release cycle to avoid site failure */

create table :SCHEMA.:CLEAN_ORG_ABBREVRefSynOrthologousGenesTmp (
  source_id text,
  ref_source_id text,
  project_id VARCHAR(30),
  org_abbrev VARCHAR(30),
  modification_date timestamp
);


:CREATE_AND_POPULATE
SELECT * FROM :SCHEMA.:CLEAN_ORG_ABBREVRefSynOrthologousGenesTmp;
:DECLARE_PARTITION;

DROP TABLE :SCHEMA.:CLEAN_ORG_ABBREVRefSynOrthologousGenesTmp;
