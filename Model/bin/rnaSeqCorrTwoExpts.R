#!/usr/bin/env Rscript

# example command line: Rscript rnaSeqCorrTwoExpts <fileName1> <fileName2> <outputFileName>
# fileName1 and fileName2 must be tab-delimited files where the first column contains the gene id,
# the subsequent columns comtain expression values, and the header contains the sample names.
# The output file will contain a matrix of correlation values calculated between pairwise samples.
# If the number of samples in the two files is equal, the diagonal of this matrix will contain the highest
# correlation values.

arguments = commandArgs(trailingOnly=TRUE)

if (length(arguments)!=3) {
  stop("Three arguments must be supplied (two input files and then an output file)", call.=FALSE)
} 

fileName1 <- arguments[1];
fileName2 <- arguments[2];
outFile <- arguments[3];

expt1 <- read.table(arguments[1],header=TRUE,sep="\t");
expt2 <- read.table(arguments[2],header=TRUE,sep="\t");

numSamples1 <- ncol(expt1) - 1;
numSamples2 <- ncol(expt2) - 1;
samples1 <- colnames(expt1)[2:(numSamples1+1)];
samples2 <- colnames(expt2)[2:(numSamples2+1)];

colnames(expt1)[1] <- "gene_id";
colnames(expt2)[1] <- "gene_id";

results <- matrix(0,nrow=numSamples1,ncol=numSamples2);
rownames(results) <- samples1[order(samples1)];
colnames(results) <- samples2[order(samples2)];

colnames(expt1)[2:(numSamples1+1)] <- paste0(rep("Expt1_",numSamples1),colnames(expt1)[2:(numSamples1+1)]);
colnames(expt2)[2:(numSamples2+1)] <- paste0(rep("Expt2_",numSamples2),colnames(expt2)[2:(numSamples2+1)]);

merged <- merge(expt1,expt2,by="gene_id");
merged <- merged[,-1];
merged <- merged[,order(colnames(merged))];

for (a in 1:numSamples1) {
  for (b in 1:numSamples2) {
    results[a,b] <- cor(as.numeric(merged[,a]),as.numeric(merged[,(b+numSamples1)]));
  }
}

write.table(results,file=outFile,sep="\t",row.names = TRUE,col.names = NA,quote=FALSE);