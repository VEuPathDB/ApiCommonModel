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
scatterFile <- paste(outFile,"pdf",sep=".");

expt1 <- read.table(arguments[1],header=TRUE,sep="\t");
expt2 <- read.table(arguments[2],header=TRUE,sep="\t");

numSamples1 <- ncol(expt1) - 1;
numSamples2 <- ncol(expt2) - 1;
samples1 <- colnames(expt1)[2:(numSamples1+1)];
samples2 <- colnames(expt2)[2:(numSamples2+1)];

colnames(expt1)[1] <- "gene_id";
colnames(expt2)[1] <- "gene_id";

results <- matrix(0,nrow=numSamples1+1,ncol=numSamples2);
rownames(results) <- c(samples1[order(samples1)],'NumGenes_Min_Max');
colnames(results) <- samples2[order(samples2)];

colnames(expt1)[2:(numSamples1+1)] <- paste0(rep("Expt1_",numSamples1),colnames(expt1)[2:(numSamples1+1)]);
colnames(expt2)[2:(numSamples2+1)] <- paste0(rep("Expt2_",numSamples2),colnames(expt2)[2:(numSamples2+1)]);

merged <- merge(expt1,expt2,by="gene_id");

numMatchingGenes = nrow(merged);
if (numMatchingGenes < 2) {
   text <- paste("num matching genes:",numMatchingGenes);
   writeLines(c(text),correlationFile);
} else {

  merged <- merged[,-1];
  merged <- merged[,order(colnames(merged))];

  results[nrow(results),1] <- paste(nrow(merged),min(merged),max(merged),sep="_");

  for (a in 1:numSamples1) {
      for (b in 1:numSamples2) {
      	  results[a,b] <- cor(as.numeric(merged[,a]),as.numeric(merged[,(b+numSamples1)]),method="spearman");
      }
  }
  write.table(results,file=correlationFile,sep="\t",row.names = TRUE,col.names = NA,quote=FALSE);

  pdf(scatterFile,width=8,height=8);
  par(mar=c(1,1,1,1))
  pairs(log10(merged+1), pch=20, cex.labels=1-0.02*numSamples1, lower.panel=NULL);
  dev.off();

}