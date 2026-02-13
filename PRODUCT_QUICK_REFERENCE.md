# Quick Reference: Gene and Transcript Product Logic

## Priority Cascades

### Gene Product Priority (source_priority / source_rule values)
1. **Preferred curated gene products** (is_preferred=1, Sanger, VEuPathDB, Apollo, GeneDB)
2. **Any curated gene products** (Sanger, VEuPathDB, Apollo, GeneDB)
3. **1:1 + Preferred curated transcript products** (is_preferred=1, Sanger, VEuPathDB, Apollo, GeneDB)
4. **1:1 + Any curated transcript products** (Sanger, VEuPathDB, Apollo, GeneDB)
5. **ARBA gene products**
6. **All gene products** (concatenated)
7. **All transcript products** (concatenated)
8. **Base gene product field** (GeneFeature.product)
9. **Base transcript products** (concatenated, Transcript.product) - *only in webready*

### Transcript Product Priority (source_priority / source_rule values)
1. **1:1 + Preferred curated gene products** (is_preferred=1, Sanger, VEuPathDB, Apollo, GeneDB)
2. **1:1 + Any curated gene products** (Sanger, VEuPathDB, Apollo, GeneDB)
3. **Preferred curated transcript products** (is_preferred=1, Sanger, VEuPathDB, Apollo, GeneDB)
4. **Any curated transcript products** (Sanger, VEuPathDB, Apollo, GeneDB)
5. **1:1 + All gene products** (concatenated)
6. **All transcript products** (concatenated)
7. **1:1 + Base gene product field** (GeneFeature.product)
8. **Base transcript product field** (Transcript.product)

## Tables and Their Purpose

### Tuning Tables (apidbtuning schema)
- **TempGeneProduct** - Correct gene products using priority logic (global, all organisms)
- **TempTranscriptProduct** - Correct transcript products using priority logic (global, all organisms)
- **GeneAttributes** - Gene record attributes (copied from webready, then product overridden)
- **TranscriptAttributes** - Transcript record attributes (copied from webready, then products overridden)

### Webready Tables (webready schema)
- **GeneProduct_p** - Gene products per organism (will be correct in next workflow)
- **TranscriptProduct_p** - Transcript products per organism (NEW, will be correct in next workflow)
- **GeneAttributes_p** - Gene record attributes (currently has FLAWED product)
- **TranscriptAttributes_p** - Transcript record attributes (currently has FLAWED gene_product and transcript_product)

## Key SQL Patterns

### 1:1 Gene:Transcript Detection (Gene perspective)
```sql
SELECT gf.na_feature_id as gene_na_feature_id,
       gf.source_id as gene_source_id,
       MAX(t.na_feature_id) as transcript_na_feature_id
FROM dots.GeneFeature gf
LEFT JOIN dots.Transcript t ON t.parent_id = gf.na_feature_id
GROUP BY gf.na_feature_id, gf.source_id
HAVING COUNT(t.na_feature_id) = 1
```

### 1:1 Gene:Transcript Detection (Transcript perspective)
```sql
SELECT t.na_feature_id as transcript_na_feature_id,
       t.source_id as transcript_source_id,
       t.parent_id as gene_na_feature_id
FROM dots.Transcript t
WHERE EXISTS (
  SELECT 1
  FROM dots.Transcript t2
  WHERE t2.parent_id = t.parent_id
  GROUP BY t2.parent_id
  HAVING COUNT(*) = 1
)
```

### Curated Source Filters

**Preferred curated products:**
```sql
WHERE assigned_by IN ('Sanger', 'VEuPathDB', 'Apollo', 'GeneDB')
  AND is_preferred = 1
```

**Any curated products:**
```sql
WHERE assigned_by IN ('Sanger', 'VEuPathDB', 'Apollo', 'GeneDB')
```

### ARBA Filter
```sql
WHERE assigned_by = 'ARBA'
```

### Product Concatenation (with 4000 char limit)
```sql
SUBSTR(STRING_AGG(DISTINCT product, ', ' ORDER BY product), 1, 4000)
```

### Priority Selection
```sql
WITH
  all_products AS (
    SELECT * FROM priority1
    UNION ALL SELECT * FROM priority2
    UNION ALL SELECT * FROM priority3
    ...
  ),
  ranked_products AS (
    SELECT source_id, product, priority,
           ROW_NUMBER() OVER (PARTITION BY source_id ORDER BY priority) as rank
    FROM all_products
  )
SELECT source_id, product, priority
FROM ranked_products
WHERE rank = 1
```

## Data Flow

```
dots.GeneFeature ─┐
dots.Transcript  ─┤
apidb.GeneFeatureProduct ─┤
apidb.TranscriptProduct ──┤
                          │
                          ├─→ webready tables ─→ apidbtuning ─→ WDK queries
                          │   (org-specific)      (global)
                          │
                          └─→ TempGeneProduct ────┐
                              TempTranscriptProduct ─→ GeneAttributes     ─→ WDK queries
                              (bypass webready!)      TranscriptAttributes
```

## Important Notes

1. **Webready tables source from dots/apidb ONLY** (never from apidbtuning)
2. **Temp tables are global** (no taxon filtering, source_id is unique)
3. **Temp tables bypass webready** (source directly from dots/apidb)
4. **Tuning tables override webready** (UPDATE statements replace flawed products)
5. **Preferred curated products first** (is_preferred=1 takes priority within curated sources)
6. **Curated sources prioritized** (Sanger, VEuPathDB, Apollo, GeneDB > ARBA > all others)
7. **1:1 relationships matter** (transcripts inherit from genes when 1:1)
8. **ARBA is automated** (lower priority than curated annotations)
9. **Multiple curated products handled** (when multiple exist from same source, preferred ones win)

## File Locations

```
Model/lib/xml/tuningManager/apiTuningManager.xml
  - Lines 7-29: GeneAttributes tuning table (modified)
  - Lines 32-74: TranscriptAttributes tuning table (modified)
  - Lines 223-355: TempGeneProduct tuning table (NEW)
  - Lines 357-491: TempTranscriptProduct tuning table (NEW)

Model/lib/psql/webready/orgSpecific/GeneProduct_p.psql
  - Complete rewrite with new priority logic

Model/lib/psql/webready/orgSpecific/TranscriptProduct_p.psql (NEW)
  - New table with transcript product priority logic

Model/lib/psql/webready/orgSpecific/TranscriptProduct_p_ix.psql (NEW)
  - Index for TranscriptProduct_p
```

## Testing Queries

### Check table counts
```sql
SELECT COUNT(*) FROM apidbtuning.TempGeneProduct;
SELECT COUNT(*) FROM apidbtuning.TempTranscriptProduct;
SELECT COUNT(*) FROM apidbtuning.GeneAttributes;
SELECT COUNT(*) FROM apidbtuning.TranscriptAttributes;
```

### Priority distribution
```sql
SELECT source_priority, COUNT(*)
FROM apidbtuning.TempGeneProduct
GROUP BY source_priority
ORDER BY source_priority;

SELECT source_priority, COUNT(*)
FROM apidbtuning.TempTranscriptProduct
GROUP BY source_priority
ORDER BY source_priority;
```

### Compare old vs new products
```sql
-- Gene products
SELECT ga.source_id,
       wga.product as old_product,
       ga.product as new_product,
       tgp.source_priority
FROM apidbtuning.GeneAttributes ga
JOIN webready.GeneAttributes_p wga ON ga.source_id = wga.source_id
LEFT JOIN apidbtuning.TempGeneProduct tgp ON ga.source_id = tgp.source_id
WHERE ga.product != wga.product
LIMIT 50;

-- Transcript products
SELECT ta.source_id,
       wta.transcript_product as old_product,
       ta.transcript_product as new_product,
       ttp.source_priority
FROM apidbtuning.TranscriptAttributes ta
JOIN webready.TranscriptAttributes_p wta ON ta.source_id = wta.source_id
LEFT JOIN apidbtuning.TempTranscriptProduct ttp ON ta.source_id = ttp.source_id
WHERE ta.transcript_product != wta.transcript_product
LIMIT 50;
```

### Sample high-priority products
```sql
-- Preferred curated gene products (priority 1)
SELECT source_id, product, source_priority, source_rule_description
FROM apidbtuning.TempGeneProduct
WHERE source_priority = 1
LIMIT 20;

-- Any curated gene products (priority 2)
SELECT source_id, product, source_priority, source_rule_description
FROM apidbtuning.TempGeneProduct
WHERE source_priority = 2
LIMIT 20;

-- Preferred curated transcript products (priority 3)
SELECT source_id, product, source_priority, source_rule_description
FROM apidbtuning.TempTranscriptProduct
WHERE source_priority = 3
LIMIT 20;

-- Any curated transcript products (priority 4)
SELECT source_id, product, source_priority, source_rule_description
FROM apidbtuning.TempTranscriptProduct
WHERE source_priority = 4
LIMIT 20;
```

## Deployment Steps

### Immediate (Short-term Fix)
1. Test SQL locally
2. Run tuningManager to build TempGeneProduct and TempTranscriptProduct
3. Run tuningManager to rebuild GeneAttributes and TranscriptAttributes (with UPDATE blocks)
4. Verify with test queries
5. Test record pages
6. Deploy to production

### Next Workflow (Long-term Fix)
1. Rebuild webready tables using new GeneProduct_p.psql
2. Build new webready table using TranscriptProduct_p.psql
3. Remove UPDATE blocks from GeneAttributes/TranscriptAttributes tuning tables
4. Remove TempGeneProduct and TempTranscriptProduct tuning tables
5. Verify download files and JBrowse have correct products
