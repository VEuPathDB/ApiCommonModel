#!/usr/bin/bash
# This is a script for creating database files for the seqret service

main(){
  # which staging directories are the current production ones?
  STAGING_DIR_PATHS_CONFIG="$1"

  # where to write the files to?
  OUTPUT_DIR="$2"

  # How to name output files?
  # Should match config: https://github.com/VEuPathDB/service-sequence-retrieval/blob/main/docker-compose/docker-compose.yml
  FASTA_SUFFIX="$3"
  SQLITE_SUFFIX="$4"

  # Which sequence types to retrieve?
  # Needs three options because of where the files live and how their headers parse:
  # - match everything before first space as the ID
  # - match "transcript(.*?) " as the ID (so we can index proteins by their transcript)
  # - dnaseq sequences, which come from the workflow dir rather than the download site
  # Any of the three may be empty, so you can rebuild just one kind of file.
  FILES_ID_BEFORE_FIRST_SPACE="${5:-}"
  FILES_ID_TRANSCRIPT_FIELD="${6:-}"
  FILES_DNASEQ="${7:-}"

  # Check the arguments and if they don't seem right print the usage message and exit
  if [ "$#" -lt 4 ] || [ "$#" -gt 7 ] \
    || [ ! "$FILES_ID_BEFORE_FIRST_SPACE" -a ! "$FILES_ID_TRANSCRIPT_FIELD" -a ! "$FILES_DNASEQ" ] \
    || [ ! -f "$STAGING_DIR_PATHS_CONFIG" ] ; then
    echo "Usage: $0 STAGING_DIR_PATHS_CONFIG OUTPUT_DIR FASTA_SUFFIX SQLITE_SUFFIX [FILES_ID_BEFORE_FIRST_SPACE] [FILES_ID_TRANSCRIPT_FIELD] [FILES_DNASEQ]"
    echo "e.g. $0 ../config/stagingDirPaths.tab ./output fa fa.fai.sqlite Genome,ESTs,Isolates AnnotatedProteins dnaseq"
    echo "     $0 ../config/stagingDirPaths.tab ./output fa fa.fai.sqlite Genome            # just the genome"
    echo "     $0 ../config/stagingDirPaths.tab ./output fa fa.fai.sqlite '' '' dnaseq      # just dnaseq"
    exit 1
  fi
  mkdir -pv $OUTPUT_DIR

  # Go through the different files that need to be made
  iterSeq "removeAfterSpaceFromHeader:$FILES_ID_BEFORE_FIRST_SPACE" \
          "chooseTranscriptFieldForHeader:$FILES_ID_TRANSCRIPT_FIELD" \
          "dnaseqHeader:$FILES_DNASEQ" \
  | while read SEQUENCE_TYPE PROG; do
    # For each desired result ...
    RESULT_SEQ_FASTA=$OUTPUT_DIR/${SEQUENCE_TYPE}.${FASTA_SUFFIX}
    RESULT_SEQ_SQLITE=$OUTPUT_DIR/${SEQUENCE_TYPE}.${SQLITE_SUFFIX}

    # Remove results of any previous run
    rm -fv $RESULT_SEQ_FASTA $RESULT_SEQ_SQLITE

    # Where do the source fastas live? dnaseq is not on the download site.
    case $PROG in
      dnaseqHeader) FIND_SOURCE_FASTAS=findDnaseqFastas ;;
      *)            FIND_SOURCE_FASTAS=findDownloadSiteFastas ;;
    esac

    # Find the source fastas and concatenate into one big fasta
    $FIND_SOURCE_FASTAS "$STAGING_DIR_PATHS_CONFIG" "$SEQUENCE_TYPE" \
    | while read -r SOURCE_FASTA; do
        echo $(date --iso=seconds) "$PROG >> $RESULT_SEQ_FASTA: $SOURCE_FASTA"
        $PROG $SOURCE_FASTA >> $RESULT_SEQ_FASTA
    done

    # Index the big fasta
    echo $(date --iso=seconds) "Indexing: $RESULT_SEQ_FASTA -> $RESULT_SEQ_SQLITE"
    indexFasta $RESULT_SEQ_FASTA $RESULT_SEQ_SQLITE
  done
}

# a little string formatting tool
iterSeq(){
  perl -E 'for (@ARGV){my ($y, $xs) = split ":"; for (split "," , $xs){say "$_ $y"}}' "$@"
}

# find files with the right name pattern
# but skip the "*Reference" versions present in staging
findInDownloadDir(){
  DOWNLOAD_DIR="$1"
  NAME_PATTERN="$2"
  find $DOWNLOAD_DIR -type f -name "$NAME_PATTERN" -a ! -wholename '*Reference/*'
}

# The usual case: one fasta per project, published on the current staging download site
findDownloadSiteFastas(){
  config="$1"
  SEQUENCE_TYPE="$2"
  readProjectAndStagingDirForGenomicSitesFromConfig $config \
  | while read PROJECT_ID STAGING_DIR; do
      findInDownloadDir ${STAGING_DIR}/downloadSite/${PROJECT_ID}/release-CURRENT "${PROJECT_ID}-CURRENT_*${SEQUENCE_TYPE}.fasta"
  done
}

# dnaseq sequences are not published on the download site - they are read straight out
# of the GenomicsDB workflow results. The config gives us the workflow data root; the
# layout underneath it is fixed:
#   <root>/<project>/<organism>/dnaseq/<experiment>/dnaseqNextflow/analysisDir/results/<sample>/<sample>_consensus.fa.gz
#   <root>/<project>/<organism>/loadGenome/genomicSeqs.fa
# Left unquoted on purpose so the shell expands the glob - much faster than find,
# which would otherwise walk the whole workflow tree.
findDnaseqFastas(){
  config="$1"
  readDnaseqWorkflowRootFromConfig $config \
  | while read -r DNASEQ_ROOT; do
      ls -1d ${DNASEQ_ROOT%/}/*/*/dnaseq/*/dnaseqNextflow/analysisDir/results/*/*_consensus.fa.gz 2>/dev/null
  done \
  | addReferenceGenomes
}

# Each organism's reference genome goes in alongside its consensus sequences, so every
# sample sits next to the reference it was called against. Only organisms that actually
# produced consensus output get one - an organism whose dnaseq directory exists but
# yielded no results contributes nothing, and so needs no reference genome.
# The paths arrive grouped by organism because the glob above is sorted, so remembering
# only the previous one is enough to emit each reference genome exactly once.
addReferenceGenomes(){
  LAST_ORGANISM_DIR=
  while read -r SOURCE_FASTA; do
    ORGANISM_DIR=${SOURCE_FASTA%%/dnaseq/*}
    if [ "$ORGANISM_DIR" != "$LAST_ORGANISM_DIR" ]; then
      REFERENCE_GENOME=$ORGANISM_DIR/loadGenome/genomicSeqs.fa
      if [ -f "$REFERENCE_GENOME" ]; then
        echo "$REFERENCE_GENOME"
      else
        echo "Warning: no reference genome at $REFERENCE_GENOME" >&2
      fi
      LAST_ORGANISM_DIR=$ORGANISM_DIR
    fi
    echo "$SOURCE_FASTA"
  done
}

readProjectAndStagingDirForGenomicSitesFromConfig(){
  config="$1"
  grep -v 'MicrobiomeDB\|ClinEpiDB\|OrthoMCL\|^dnaseqWorkflowRoot\|^$' $config
}

readDnaseqWorkflowRootFromConfig(){
  config="$1"
  awk '$1 == "dnaseqWorkflowRoot" {print $2}' $config
}

removeAfterSpaceFromHeader(){
  # Match a space or tab rather than \s - \s also matches the newline that -p leaves on
  # $_, so a header with no description would lose its newline and get the first line of
  # sequence joined onto the ID.
  perl -pe 's{[ \t].*$}{} if m{^>}' "$@"
}

chooseTranscriptFieldForHeader(){
  perl -pe 'if(m{^>} and m{transcript=(.*?) }){$_ = ">$1\n";}' "$@"
}

# The consensus fastas are bgzipped and the reference genomes are not, so decompress only
# what needs it. Consensus headers are already "<sample>_<contig>" with no description,
# which keeps IDs unique across samples, and reference headers are bare contig IDs - the
# ID rule is the same as for the download site fastas either way.
dnaseqHeader(){
  case "$1" in
    *.gz) zcat "$@" ;;
    *)    cat  "$@" ;;
  esac | removeAfterSpaceFromHeader
}

indexFasta(){
  INPUT_FASTA_PATH="$1"
  OUTPUT_SQLITE_PATH="$2"
  
  ABS_DIR=$( cd $(dirname $INPUT_FASTA_PATH) && pwd )
  NAME=$(basename $INPUT_FASTA_PATH)
  singularity run  --bind $ABS_DIR:/work \
    https://depot.galaxyproject.org/singularity/pyfaidx%3A0.7.1--pyh5e36f6f_0 \
    faidx --invert-match /work/$NAME
  if ! [ -f "${INPUT_FASTA_PATH}.fai" ] ; then
    echo "Error: ${INPUT_FASTA_PATH}.fai not found - did Singularity+faidx work?"
    exit 1
  fi
  # The big fasta is a concatenation of many independently made files, so check the IDs
  # are unique before importing - otherwise the unique index below aborts the .import
  # part way through and leaves a half filled database behind.
  DUPLICATE_IDS=$(cut -f1 "${INPUT_FASTA_PATH}.fai" | sort | uniq -d | head)
  if [ -n "$DUPLICATE_IDS" ] ; then
    echo "Error: duplicate sequence IDs in ${INPUT_FASTA_PATH}, first few:"
    echo "$DUPLICATE_IDS"
    exit 1
  fi

  # Column names follow documentation here: http://www.htslib.org/doc/faidx.html
  # Table name and columns are expected by the service
  rm -f "$OUTPUT_SQLITE_PATH"
  sqlite3 "$OUTPUT_SQLITE_PATH" <<EOF
create table faidx (
  name text not null,
  length number not null,
  offset number not null,
  linebases number,
  linewidth number
);
create unique index faidx_name on faidx (name);
.mode tabs
.import ${INPUT_FASTA_PATH}.fai faidx
EOF
  # sqlite3 always creates its database 0644, and a umask can only clear permission bits
  # rather than add them, so make the results group writable here instead.
  chmod -v g+w "$INPUT_FASTA_PATH" "$OUTPUT_SQLITE_PATH"
  if ! [ -f "${OUTPUT_SQLITE_PATH}" ] ; then
    echo "Error: ${OUTPUT_SQLITE_PATH} not found - did sqlite3 work?"
    exit 1
  fi
  rm ${INPUT_FASTA_PATH}.fai
}

# Done so the script can be sourced and tested bit by bit
# https://stackoverflow.com/a/23009039
if [ "$0" = "$BASH_SOURCE" ]; then
  main "$@"
fi
