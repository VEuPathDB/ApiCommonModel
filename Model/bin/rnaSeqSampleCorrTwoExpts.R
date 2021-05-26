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
correlationFile <- paste(outFile,"txt",sep=".");

expt1 <- read.table(fileName1,header=TRUE,sep="\t");
expt2 <- read.table(fileName2,header=TRUE,sep="\t");

numSamples1 <- ncol(expt1) - 1;
numSamples2 <- ncol(expt2) - 1;
samples1 <- colnames(expt1)[2:(numSamples1+1)];
samples2 <- colnames(expt2)[2:(numSamples2+1)];
colnames(expt1)[2:(numSamples1+1)] <- paste0(rep("Expt1_",numSamples1),samples1);
colnames(expt2)[2:(numSamples2+1)] <- paste0(rep("Expt2_",numSamples2),samples2);
colnames(expt1)[1] <- "gene_id";
colnames(expt2)[1] <- "gene_id";

results <- matrix(0,nrow=numSamples1+1,ncol=numSamples2);
rownames(results) <- c(samples1,'NumGenes_Min_Max');
colnames(results) <- samples2;

lowest <- 100000;
highest <- 0;
leastMatchingGenes <- 1000000;

for (a in 1:numSamples1) {
       for (b in 1:numSamples2) {
       	   merged <- merge(expt1[,c(1,a+1)],expt2[,c(1,b+1)],by="gene_id");

	   numMatchingGenes <- nrow(merged);
      	   if (numMatchingGenes < leastMatchingGenes) {
      	        leastMatchingGenes <- numMatchingGenes;
           }
	   if (numMatchingGenes < 2) {
	        results[a,b] <- 10;
	   } else {

	        merged <- merged[,-1];
		currentLowest <- min(merged);
		currentHighest <- max(merged);
		if (currentLowest < lowest) {
		     lowest <- currentLowest;
		}
		if (currentHighest > highest) {
		     highest <- currentHighest;
		}
		results[a,b] <- cor(as.numeric(merged[,1]),as.numeric(merged[,2]),method="spearman");
           }
       }
}

results[nrow(results),1] <- paste(leastMatchingGenes,lowest,highest,sep="_");

write.table(results,file=correlationFile,sep="\t",row.names = TRUE,col.names = NA,quote=FALSE);