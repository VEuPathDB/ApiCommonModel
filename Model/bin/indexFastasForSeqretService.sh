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
  # Needs two options because of parsing headers difference:
  # - match everything before first space as the ID
  # - match "transcript(.*?) " as the ID (so we can index proteins by their transcript)
  FILES_ID_BEFORE_FIRST_SPACE="$5"
  FILES_ID_TRANSCRIPT_FIELD="$6"

  # Check the arguments and if they don't seem right print the usage message and exit
  if [ "$#" -ne 6 ] || [ ! "$FILES_ID_BEFORE_FIRST_SPACE" -a ! "$FILES_ID_TRANSCRIPT_FIELD" ] || [ ! -f "$STAGING_DIR_PATHS_CONFIG" ] ; then
    echo "Usage: $0 STAGING_DIR_PATHS_CONFIG OUTPUT_DIR FASTA_SUFFIX SQLITE_SUFFIX FILES_ID_BEFORE_FIRST_SPACE FILES_ID_TRANSCRIPT_FIELD"
    echo "e.g. $0 ../config/stagingDirPaths.tab ./output fa fa.fai.sqlite Genome,ESTs,Isolates AnnotatedProteins"
    exit 1
  fi
  mkdir -pv $OUTPUT_DIR

  # Go through the different files that need to be made
  iterSeq "removeAfterSpaceFromHeader:$FILES_ID_BEFORE_FIRST_SPACE" "chooseTranscriptFieldForHeader:$FILES_ID_TRANSCRIPT_FIELD" \
  | while read SEQUENCE_TYPE PROG; do
    # For each desired result ...
    RESULT_SEQ_FASTA=$OUTPUT_DIR/${SEQUENCE_TYPE}.${FASTA_SUFFIX}
    RESULT_SEQ_SQLITE=$OUTPUT_DIR/${SEQUENCE_TYPE}.${SQLITE_SUFFIX}

    # Remove results of any previous run
    rm -fv $RESULT_SEQ_FASTA $RESULT_SEQ_SQLITE

    # Find fastas in staging dir and concatenate into one big fasta
    readProjectAndStagingDirForGenomicSitesFromConfig $STAGING_DIR_PATHS_CONFIG \
    | while read PROJECT_ID STAGING_DIR; do
      findInDownloadDir ${STAGING_DIR}/downloadSite/${PROJECT_ID}/release-CURRENT "${PROJECT_ID}-CURRENT_*${SEQUENCE_TYPE}.fasta" \
      | while read -r SOURCE_FASTA; do
          echo $(date --iso=seconds) "$PROG >> $RESULT_SEQ_FASTA: $SOURCE_FASTA"
          $PROG $SOURCE_FASTA >> $RESULT_SEQ_FASTA
      done
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

readProjectAndStagingDirForGenomicSitesFromConfig(){
  config="$1"
  grep -v 'MicrobiomeDB\|ClinEpiDB\|OrthoMCL\|^$' $config
}

removeAfterSpaceFromHeader(){
  perl -pe 's{\s.*$}{} if m{^>}' "$@"
}

chooseTranscriptFieldForHeader(){
  perl -pe 'if(m{^>} and m{transcript=(.*?) }){$_ = ">$1\n";}' "$@"
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
