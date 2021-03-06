#############################
# Function to plot Expression
#############################

plotGenes <- function(myRNASeqAnalysisOut = RNASeqAnalysisOut) {
  geneData <- myRNASeqAnalysisOut[[1]][[2]]
  geneData <- geneData %>%
    rownames_to_column("Gene") %>%
    mutate(Direction = ifelse(Z_Score > 0, "Up", "Down")) %>%
    arrange(Z_Score)
  geneData$Gene <- factor(geneData$Gene, levels = geneData$Gene)
  p <- ggplot(geneData, aes(Gene, y = Z_Score, fill = Direction)) + 
    geom_bar(stat="identity") + coord_flip() + theme_bw() + 
    xlab("Gene Symbol") + scale_fill_manual(values = c("Down" = "forest green", 
                                                       "Up" = "red"))
  return(p)
}