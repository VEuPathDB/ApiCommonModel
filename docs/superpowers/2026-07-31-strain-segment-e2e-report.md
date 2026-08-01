# End-to-end testing: strain genomic segment search

**Instance:** FungiDB dev, `jbrestel.fungidb.org` · **appDb:** `unidb_shu_a` · **Date:** 2026-07-31

## What it does

A new internal search takes a **strain name** and a **reference-coordinate location**
(sequence ID, start, end, strand) as input, and returns that segment expressed in the
strain's own consensus-sequence coordinates as a BED feature. Strain names come from a
controlled vocabulary; the coordinate conversion prefix-sums the per-event shifts recorded
for that strain.

Testing exercised the whole path against the running site — search, coordinate conversion,
BED download — and then checked the result against the actual strain consensus FASTA files
the BED is meant to index into.

The search returns an empty result rather than an error for invalid input: a strain paired
with another organism's sequence, or a range beyond the sequence length, both come back
empty. A successful download leaves every error log silent.

## BED output

Input: strain + `Chr1_A_fumigatus_Af293`, reference `396000-399000`, forward. Five strains,
one search each. Column 1 is the strain FASTA key, columns 2–3 the strain coordinates (BED
start is 0-based), column 4 the record ID carrying the reference coordinates requested.

```
A17-10A-1_Chr1_A_fumigatus_Af293  395992  398982  A17-10A-1:Chr1_A_fumigatus_Af293:396000-399000:f  0  +
A17-3C-11_Chr1_A_fumigatus_Af293  396006  398996  A17-3C-11:Chr1_A_fumigatus_Af293:396000-399000:f  0  +
A17-58A-3_Chr1_A_fumigatus_Af293  395999  399000  A17-58A-3:Chr1_A_fumigatus_Af293:396000-399000:f  0  +
B-1-71L-1_Chr1_A_fumigatus_Af293  396035  399036  B-1-71L-1:Chr1_A_fumigatus_Af293:396000-399000:f  0  +
E-1-75s-2_Chr1_A_fumigatus_Af293  395987  398984  E-1-75s-2:Chr1_A_fumigatus_Af293:396000-399000:f  0  +
```

One reference interval, five different strain intervals — different offsets and different
lengths (reference 3001 bp; strains 2990, 2990, 3001, 3001, 2997). Every column-1 value
matched a defline in the corresponding `<strain>_consensus.fa.gz` byte-for-byte.

## Alignment

Reference substrings came from the database and strain substrings from the consensus FASTAs,
extracted with `samtools faidx` at exactly the coordinates the search returned, then aligned
with `clustalo`.

### Chr1, reference 396000–399000

Alignment length 3001, the same as the reference.

| sequence | gaps | identity vs reference |
|---|---:|---:|
| REFERENCE | 0 | 100.000% |
| A17-10A-1 | 11 | 99.799% |
| A17-3C-11 | 11 | 99.799% |
| A17-58A-3 | 0 | 99.867% |
| B-1-71L-1 | 0 | 99.667% |
| E-1-75s-2 | 4 | 99.766% |

Columns 1196–1240, an 11 bp deletion in two strains:

```
REFERENCE   GTGGTATTGCTTCTTCCATCAAACTTCTACAGAGCACAGCGGCTA
A17-10A-1   GTGGTATTGCTTCTT-----------CTACAGAGCACAGCGGCTA
A17-3C-11   GTGGTATTGCTTCTT-----------CTACAGAGCACAGCGGCTA
A17-58A-3   GTGGTATTGCTTCTTCCATCAAACTTCTACAGAGCACAGCGGCTA
B-1-71L-1   GTGGTATTGCTTCTTCCATCAAACTTCTACAGAGCACMGCGGCTA
E-1-75s-2   GTGGTATTGCTTCTTCCATCAAACTTCTACAGAGCACCGCGGCTA
```

Gap sizes match the recorded indels exactly: 11 bp in two strains, 4 bp in a third, and no
gap in the two with no recorded event.

### mito, reference 500–2000

No strain has an indel before position 2000 here, so all five map to the identical interval
and the alignment is the expected degenerate case — length 1501, no gaps anywhere, four of
five strains identical to the reference.

| sequence | gaps | identity vs reference |
|---|---:|---:|
| REFERENCE | 0 | 100.000% |
| A17-10A-1 | 0 | 100.000% |
| A17-3C-11 | 0 | 100.000% |
| A17-58A-3 | 0 | 100.000% |
| B-1-71L-1 | 0 | 100.000% |
| E-1-75s-2 | 0 | 99.933% |

Columns 401–460:

```
REFERENCE   TCTAGCATTAATGGTTATGCCTATAACTGATTTATCTAAATTAAGAGGAGTACAGTTCAG
A17-10A-1   TCTAGCATTAATGGTTATGCCTATAACTGATTTATCTAAATTAAGAGGAGTACAGTTCAG
A17-3C-11   TCTAGCATTAATGGTTATGCCTATAACTGATTTATCTAAATTAAGAGGAGTACAGTTCAG
A17-58A-3   TCTAGCATTAATGGTTATGCCTATAACTGATTTATCTAAATTAAGAGGAGTACAGTTCAG
B-1-71L-1   TCTAGCATTAATGGTTATGCCTATAACTGATTTATCTAAATTAAGAGGAGTACAGTTCAG
E-1-75s-2   TCTAGCATTAATGGTTATGCCTATAACTGATTTATCTAAATTAAGAGGAGTACAGTTCAG
```

mito is worth including because it was **broken until this round**. The search originally
required a strain to have indel data on the exact sequence requested, so a contig a strain
simply matches returned nothing at all — even though the contig is present in that strain's
FASTA. That refused **689 of 6,068** valid strain/sequence combinations (11%). The check is
now scoped to the organism, which still confirms the strain and sequence go together while
allowing the identity mapping.

## Control and limitation

To confirm the conversion does real work, the strain sequence was also pulled at the
**unshifted** reference coordinates. Against the reference, the converted coordinates give
**99.92%** identity; the unshifted control gives **25.0%**, which is chance.

One limitation, a property of the data rather than the implementation: if a requested
boundary falls inside a deletion, that reference base does not exist in the strain, so there
is no exact strain coordinate for it. Boundaries outside any deletion — the ordinary case,
and every case above — convert exactly.
