#!/usr/bin/bash
# This is a script for creating database files for the seqret service

main(){
  # allow data from staging dir for the coming release, or from the download site for any release
  INPUT_BASE_DIR="$1" 
  RELEASE_NUMBER_OR_CURRENT="$2"

  # needs to match sync source
  OUTPUT_DIR="$3"

  # How to name output files?
  # Should match service config
  # See: https://github.com/VEuPathDB/service-sequence-retrieval/blob/main/docker-compose/docker-compose.yml
  FASTA_SUFFIX="$4"
  SQLITE_SUFFIX="$5"

  # Which sequence types to retrieve?
  # Needs two options because of parsing headers difference:
  # - match everything before first space as the ID
  # - match "transcript(.*?) " as the ID (so we can index proteins by their transcript)
  FILES_ID_BEFORE_FIRST_SPACE="$6"
  FILES_ID_TRANSCRIPT_FIELD="$7"

  if [ "$#" -ne 7 ] || [ ! "$FILES_ID_BEFORE_FIRST_SPACE" -a ! "$FILES_ID_TRANSCRIPT_FIELD" ] ; then
    echo "Usage: $0 INPUT_BASE_DIR RELEASE_NUMBER_OR_CURRENT OUTPUT_DIR FASTA_SUFFIX SQLITE_SUFFIX FILES_ID_BEFORE_FIRST_SPACE FILES_ID_TRANSCRIPT_FIELD"
    echo "e.g. to sync protein and ESTs only, from the staging data folder:"
    echo "  $0 /eupath/data/apiSiteFilesStaging CURRENT ./output fa fa.fai.sqlite Genome,ESTs,Isolates AnnotatedProteins"
    echo "Or, to get all the sequences, corresponding to release 59:"
    echo "  $0 /eupath/data/apiSiteFiles/downloadSite 59 ./output fa fa.fai.sqlite Genome,ESTs,Isolates AnnotatedProteins"
    exit 1
  fi
  mkdir -pv $OUTPUT_DIR

  iterSeq "removeAfterSpaceFromHeader:$FILES_ID_BEFORE_FIRST_SPACE" "chooseTranscriptFieldForHeader:$FILES_ID_TRANSCRIPT_FIELD" \
  | while read SEQUENCE_TYPE PROG; do
    RESULT_SEQ_FASTA=$OUTPUT_DIR/${SEQUENCE_TYPE}.${FASTA_SUFFIX}
    RESULT_SEQ_SQLITE=$OUTPUT_DIR/${SEQUENCE_TYPE}.${SQLITE_SUFFIX}
    # Remove results of any previous run
    rm -fv $RESULT_SEQ_FASTA $RESULT_SEQ_SQLITE

    walkGenomicDownloadDirs $INPUT_BASE_DIR $RELEASE_NUMBER_OR_CURRENT \
    | while read PROJECT_ID DOWNLOAD_DIR; do
      findInDownloadDir $DOWNLOAD_DIR "${PROJECT_ID}-${RELEASE_NUMBER_OR_CURRENT}_*${SEQUENCE_TYPE}.fasta" \
      | while read -r SOURCE_FASTA; do
          echo $(date --iso=seconds) "$PROG >> $RESULT_SEQ_FASTA: $SOURCE_FASTA"
          $PROG $SOURCE_FASTA >> $RESULT_SEQ_FASTA
      done
    done

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



walkGenomicDownloadDirs(){
  INPUT_BASE_DIR="$1"
  RELEASE_NUMBER_OR_CURRENT="$2"
  find $INPUT_BASE_DIR  -maxdepth 1 -type d \( -name '*DB' -a ! -name 'MicrobiomeDB' -a ! -name 'SchistoDB' -a ! -name 'ClinEpiDB' -a ! -name 'UniDB' \) -o -name 'VectorBase' | while read -r d; do
    PROJECT_ID=$(basename "$d" )
    if [ -d $d/release-${RELEASE_NUMBER_OR_CURRENT} ] ; then
      echo $PROJECT_ID $d/release-${RELEASE_NUMBER_OR_CURRENT}
    else
      leaves=$(find $d -maxdepth 6 -regex "$d/[0-9]+/real/downloadSite/.*/release-${RELEASE_NUMBER_OR_CURRENT}" )
      if [ "$leaves" ] ; then
        echo $PROJECT_ID $( ls -dt $leaves | head -n1 )
      fi
    fi
  done
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
