# Implementation Summary: TempGeneProduct and TempTranscriptProduct

## Overview
Successfully implemented a two-pronged solution to fix flawed gene and transcript product logic in the system.

## Files Modified

### 1. Model/lib/xml/tuningManager/apiTuningManager.xml
**Changes:**
- **Added TempGeneProduct tuning table** (after line 190)
  - Sources from dots.GeneFeature, dots.Transcript, apidb.GeneFeatureProduct, apidb.TranscriptProduct
  - Implements 6-level priority cascade for gene products
  - Global table (all organisms)
  - Includes unique index on source_id and index on source_priority

- **Added TempTranscriptProduct tuning table** (after TempGeneProduct)
  - Sources from same dots/apidb tables
  - Implements 6-level priority cascade for transcript products
  - Global table (all organisms)
  - Includes unique index on source_id and index on source_priority

- **Modified GeneAttributes tuning table**
  - Added `<internalDependency name="TempGeneProduct"/>`
  - Added UPDATE statement to override product field from TempGeneProduct
  - Keeps simple CREATE TABLE from webready, then overrides flawed product

- **Modified TranscriptAttributes tuning table**
  - Added `<internalDependency name="TempGeneProduct"/>`
  - Added `<internalDependency name="TempTranscriptProduct"/>`
  - Added UPDATE statements to override gene_product and transcript_product fields
  - Keeps simple CREATE TABLE from webready, then overrides flawed products

### 2. Model/lib/psql/webready/orgSpecific/GeneProduct_p.psql
**Complete rewrite** with new priority logic:
1. Curated GeneFeatureProduct (Sanger|VEuPathDB|Apollo)
2. 1:1 Gene:Transcript + Curated TranscriptProduct (Sanger|VEuPathDB|Apollo)
3. ARBA GeneFeatureProduct
4. All GeneFeatureProduct (concatenated)
5. All TranscriptProduct (concatenated)
6. GeneFeature.product (base field)
7. Transcript.product (base field, concatenated)

Uses CTE-based approach with ROW_NUMBER() for priority selection.

### 3. Model/lib/psql/webready/orgSpecific/TranscriptProduct_p.psql (NEW FILE)
**New webready table** for transcript products with priority logic:
1. 1:1 Gene:Transcript + Curated GeneFeatureProduct (Sanger|VEuPathDB|Apollo)
2. Curated TranscriptProduct (Sanger|VEuPathDB|Apollo)
3. 1:1 Gene:Transcript + All GeneFeatureProduct (concatenated)
4. All TranscriptProduct (concatenated)
5. 1:1 Gene:Transcript + GeneFeature.product
6. Transcript.product (base field)

Uses same CTE-based approach as GeneProduct_p.

### 4. Model/lib/psql/webready/orgSpecific/TranscriptProduct_p_ix.psql (NEW FILE)
Index file for TranscriptProduct_p table:
- Creates index on (org_abbrev, source_id, product)

## Implementation Approach

### Short-term Fix (Immediate)
- **TempGeneProduct** and **TempTranscriptProduct** tuning tables provide correct products immediately
- **GeneAttributes** and **TranscriptAttributes** tuning tables use UPDATE to override webready products
- Website record pages will show correct products as soon as tuning tables are rebuilt

### Long-term Fix (Next Workflow)
- **GeneProduct_p.psql** rewritten with correct logic for next workflow iteration
- **TranscriptProduct_p.psql** created with correct logic for next workflow iteration
- Download files and JBrowse will have correct products in next release

## Key Design Decisions

1. **Global Tables**: TempGeneProduct and TempTranscriptProduct are global (no taxon filtering)
   - Source_id is globally unique across all organisms
   - Simpler SQL, no need for organism-specific filtering

2. **UPDATE Pattern**: Tuning tables keep simple CREATE from webready, then UPDATE product fields
   - Clear separation of concerns
   - Easy to remove UPDATE blocks when webready tables are fixed
   - Transparent about what's being overridden

3. **CTE-based Priority Logic**: All SQL uses CTEs with UNION ALL and ROW_NUMBER()
   - Clear priority cascade
   - Single SELECT at the end chooses highest priority
   - Easy to understand and maintain

4. **1:1 Relationship Detection**: Uses HAVING COUNT() = 1 in subquery
   - Identifies genes with exactly one transcript
   - Used in both gene and transcript product logic

5. **Curated Source Priority**: Prioritizes Sanger, VEuPathDB, Apollo annotations
   - These are manually curated, higher quality
   - ARBA is automated annotation, lower priority

## SQL Pattern Example

```sql
WITH
  -- Identify 1:1 relationships
  one_to_one_genes AS (
    SELECT gf.na_feature_id, gf.source_id, MAX(t.na_feature_id)
    FROM dots.GeneFeature gf
    LEFT JOIN dots.Transcript t ON t.parent_id = gf.na_feature_id
    GROUP BY gf.na_feature_id, gf.source_id
    HAVING COUNT(t.na_feature_id) = 1
  ),

  -- Priority CTEs
  gene_curated AS (...),
  transcript_curated_one_to_one AS (...),
  gene_arba AS (...),
  ...

  -- Combine all priorities
  all_products AS (
    SELECT * FROM gene_curated
    UNION ALL SELECT * FROM transcript_curated_one_to_one
    UNION ALL SELECT * FROM gene_arba
    ...
  ),

  -- Select highest priority
  ranked_products AS (
    SELECT source_id, product, priority,
           ROW_NUMBER() OVER (PARTITION BY source_id ORDER BY priority) as rank
    FROM all_products
  )
SELECT source_id, product, priority
FROM ranked_products
WHERE rank = 1
```

## Testing Plan

### Step 1: Build Tuning Tables
```bash
cd /home/jbrestel/workspaces/dataLoad/project_home/ApiCommonModel
tuningManager -instance <instance> -propFile <props> -doUpdate \
  -configFile Model/lib/xml/tuningManager/apiTuningManager.xml
```

### Step 2: Verify Table Creation
```sql
-- Check tables exist and have data
SELECT COUNT(*) FROM apidbtuning.TempGeneProduct;
SELECT COUNT(*) FROM apidbtuning.TempTranscriptProduct;

-- Check priority distribution
SELECT source_priority, COUNT(*)
FROM apidbtuning.TempGeneProduct
GROUP BY source_priority ORDER BY source_priority;
```

### Step 3: Compare Products
```sql
-- Compare old vs new gene products
SELECT ga.source_id,
       wa.product as old_product,
       ga.product as new_product,
       tgp.source_priority
FROM apidbtuning.GeneAttributes ga
JOIN webready.GeneAttributes_p wa ON ga.source_id = wa.source_id
LEFT JOIN apidbtuning.TempGeneProduct tgp ON ga.source_id = tgp.source_id
WHERE ga.product != wa.product
LIMIT 50;

-- Verify curated sources are prioritized
SELECT tgp.source_id, tgp.product, tgp.source_priority
FROM apidbtuning.TempGeneProduct tgp
WHERE tgp.source_priority IN (1, 2)
LIMIT 20;
```

### Step 4: Test Record Pages
- Visit gene record pages: https://<site>/gene/<gene_source_id>
- Visit transcript record pages: https://<site>/transcript/<transcript_source_id>
- Verify correct products are displayed

## Architecture Notes

- **Data Flow**: dots/apidb → webready → apidbtuning → WDK
- **Webready Rule**: Webready tables CANNOT reference apidbtuning tables
- **Tuning Table Exception**: TempGeneProduct and TempTranscriptProduct source directly from dots/apidb (bypass webready)
- **Tuning Table Usage**: GeneAttributes and TranscriptAttributes use internalDependency to JOIN with temp tables
- **No WDK Changes**: geneAttributeQueries.xml and transcriptAttributeQueries.xml already query the product field

## Benefits

1. **Immediate Fix**: Record pages show correct products as soon as tuning tables rebuild
2. **No WDK Changes**: Existing queries already use the product field from attributes tables
3. **Clean Separation**: UPDATE blocks in tuning tables can be easily removed when webready is fixed
4. **Backward Compatible**: old_product field preserved for comparison
5. **Next Workflow Ready**: Webready tables have correct logic for next iteration
6. **Clear Priority**: Cascading logic is easy to understand and maintain
7. **Curated First**: Manually curated annotations prioritized over automated ones

## Next Steps

1. Test SQL locally before running tuningManager
2. Run tuningManager to build TempGeneProduct and TempTranscriptProduct
3. Verify table creation and priority distribution
4. Run tuningManager to rebuild GeneAttributes and TranscriptAttributes with UPDATE blocks
5. Compare old vs new products with test queries
6. Spot-check record pages to verify correct products displayed
7. Get user approval before deploying to production
8. Document for next workflow: rebuild webready tables with new GeneProduct_p.psql and TranscriptProduct_p.psql
