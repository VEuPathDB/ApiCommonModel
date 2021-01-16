#!/usr/bin/env Rscript

# example command line: Rscript rnaSeqCorrManyExpts <fileName1,fileName2,fileName3> <outputFileName>
# fileName1,fileName2,etc must be tab-delimited files where the first column contains the gene id,
# the subsequent columns contain expression values, and the header contains the sample names.
# The output file will contain a table of correlation values calculated between all pairwise samples.
# Also included in the output file are the summary statistics for each group where a group is (1) all
# comparisons in one experiment or (2) all comparisons between expt1 and expt2

arguments = commandArgs(trailingOnly=TRUE);

if (length(arguments)!=2) {
  stop("Two arguments must be supplied (comma-separated input files and an output file)", call.=FALSE);
} 

exptNames <- unlist(strsplit(arguments[1], ","));
outputFile <- arguments[2];

numExpts <- length(exptNames);
numSamples <- rep(0,numExpts);

for (i in 1:numExpts) {
  numSamples[i] <- max(count.fields(exptNames[i], sep = "\t")) - 1;
}

# make data.frame
# Type(summary or individual) Expt1 Sample Expt2 Sample cor avg min max
# total # pairs = numSamples*(numSamples-1)/2
# total # summaries = numExpts + numExpts*(numExpts-1)/2

totalNumSamples <- sum(numSamples);
numSamplePairs <- totalNumSamples*(totalNumSamples-1)/2;
numSummaries <- numExpts + numExpts*(numExpts-1)/2;
numRows <- numSamplePairs + numSummaries;
outputTable <- data.frame(Type=rep("Individual",numRows),Expt1="",Sample1="",Expt2="",Sample2="",Cor=0,Avg=0,Min=0,Max=0,stringsAsFactors = FALSE);

# loop through expts
# loop through first sample
# loop through second sample

currentRow=1;
for (a in 1:numExpts) {
  if (numSamples[a] == 1) {   # only 1 sample in an expt so create a summary with zeroes
    outputTable$Type[currentRow]="Summary";
    outputTable$Expt1[currentRow]=exptNames[a];
    outputTable$Sample1[currentRow]="only 1 sample";
    currentRow <- currentRow + 1;
    next;
  }
  exptTable <- read.table(exptNames[a],header=TRUE,sep="\t");
  
  numComparisons <- numSamples[a] * (numSamples[a]-1) / 2;
  correlations <- rep(0,numComparisons);
  
  currentComparison <- 1;
  for (b in 2:numSamples[a]) {
    for (c in (b+1):(numSamples[a]+1)) {
      exptMatrix <- as.matrix(exptTable[,c(b,c)]);
      correlation <- cor(exptMatrix[,1],exptMatrix[,2]);
      outputTable$Cor[currentRow] <- correlation;
      correlations[currentComparison] <- correlation;
      outputTable$Expt1[currentRow] <- exptNames[a];
      outputTable$Expt2[currentRow] <- exptNames[a];
      outputTable$Sample1[currentRow] <- colnames(exptTable)[b];
      outputTable$Sample2[currentRow] <- colnames(exptTable)[c];
      currentRow <- currentRow + 1;
      currentComparison <- currentComparison + 1;
    }
  }
  outputTable$Type[currentRow]="Summary";
  outputTable$Expt1[currentRow] <- exptNames[a];
  outputTable$Expt2[currentRow] <- exptNames[a];
  outputTable$Avg[currentRow] <- mean(correlations);
  outputTable$Min[currentRow] <- min(correlations);
  outputTable$Max[currentRow] <- max(correlations);
  currentRow <- currentRow + 1;
}

# loop throug expt1
# loop through expt2
# loop through samples in expt1
# loop through samples in expt2

for (a in 1:(numExpts-1)) {
  exptTable1 <- read.table(exptNames[a],header=TRUE,sep="\t");
  colnames(exptTable1)[1] <- "gene_id";

  for (b in (a+1):numExpts) {
    exptTable2 <- read.table(exptNames[b],header=TRUE,sep="\t");
    colnames(exptTable2)[1] <- "gene_id";

    mergedTable <- merge(exptTable1,exptTable2,by="gene_id");
    mergedTable <- mergedTable[,-1];
    
    numComparisons <- numSamples[a] * numSamples[b];
    correlations <- rep(0,numComparisons);
    
    currentComparison <- 1;
    for (c in 1:numSamples[a]) {
      for (d in (numSamples[a]+1):(numSamples[a]+numSamples[b])) {
        exptMatrix <- as.matrix(mergedTable[,c(c,d)]);
        correlation <- cor(exptMatrix[,1],exptMatrix[,2]);
        outputTable$Cor[currentRow] <- correlation;
        correlations[currentComparison] <- correlation;
        outputTable$Expt1[currentRow] <- exptNames[a];
        outputTable$Expt2[currentRow] <- exptNames[b];
        outputTable$Sample1[currentRow] <- colnames(exptTable1)[c+1];
        outputTable$Sample2[currentRow] <- colnames(exptTable2)[d-numSamples[a]+1];
        currentRow <- currentRow + 1;
        currentComparison <- currentComparison + 1;
      }
    }
    outputTable$Type[currentRow]="Summary";
    outputTable$Expt1[currentRow] <- exptNames[a];
    outputTable$Expt2[currentRow] <- exptNames[b];
    outputTable$Avg[currentRow] <- mean(correlations);
    outputTable$Min[currentRow] <- min(correlations);
    outputTable$Max[currentRow] <- max(correlations);
    currentRow <- currentRow + 1;
  }
}

write.table(outputTable,file=outputFile,sep="\t",row.names = FALSE,col.names = TRUE,quote=FALSE);

warnings();
