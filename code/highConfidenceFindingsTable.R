#############################
# High Confidence Alterations
#############################

remComma <- function(x) {
  out <- substr(x, nchar(x), nchar(x))
  out <- ifelse(out==",", substr(x, 1, nchar(x)-1), x)
  return(out)
}

getGeneFromMut <- function(x) {
  myGene <- strsplit(x, ":")[[1]][[1]]
  return(myGene)
}

getGeneFromFus <- function(x) {
  myGene1 <- strsplit(x, "_")[[1]][[1]]
  myGene2 <- strsplit(x, "_")[[1]][[2]]
  return(c(myGene1, myGene2))
}

highConfidenceFindingsTable <- function(delRPKM = 10) {

  myTable <- allFindingsTable()
  myTable <- myTable[!grepl("Pathway", myTable[,"Type"]),]
  myTable <- myTable[!grepl("Outlier", myTable[,"Type"]),]

  # expression is critical
  if(exists('expData')){
    rnaEvidence <-   RNASeqAnalysisOut[[3]]
    rnaEvidence[,"Gene"] <- rownames(rnaEvidence)
    
    # Get only significant sets with adj. pvalue < 0.05
    sigGeneSets <- RNASeqAnalysisOut[[2]][[2]]
    sigGeneSets <- sigGeneSets[which(sigGeneSets$ADJ_P_VALUE < 0.05),]
    sigGeneSets <- sigGeneSets[,c("Pathway", "Direction")]
    geneSetTS.sub <- merge(geneSetTS, sigGeneSets, by.x="ind", by.y="Pathway")
    geneSetTS.sub[,"ind"] <- paste(geneSetTS.sub[,"ind"], "(",geneSetTS.sub[,"Direction"], ")", sep="")
    geneSetTS.sub <- geneSetTS.sub[,c("ind", "values")]
    geneSetTS.sub <- geneSetTS.sub %>% 
      group_by(values) %>% 
      dplyr::summarize(ind=paste(ind, collapse=","))
    geneSetTS.sub <- data.frame(geneSetTS.sub)
    
    # Supporting Evidence for Deletions
    myTableDel <- myTable[myTable$Type == "Deletion",]
    if(nrow(myTableDel) > 0){
      myTableDel <- merge(myTableDel, rnaEvidence, by.x="Aberration", by.y="Gene", all.x=T)
      myTableDel <- merge(myTableDel, geneSetTS.sub, by.x="Aberration", by.y="values", all.x=T)
      myTableDel <- myTableDel[which(myTableDel[,sampleInfo$subjectID]<10),]
      if(nrow(myTableDel)>0) {
        myTableDel[,"SupportEv"] <- paste("TPM=", myTableDel[,sampleInfo$subjectID], ifelse(is.na(myTableDel[,"ind"]), "", paste(", Pathway: ", myTableDel[,"ind"], sep="")), sep="")
        myTableDel <- myTableDel[,c("Aberration", "Type", "Details", "Drugs", "SupportEv")]
      } else {
        colnames(myTableDel) <- c("Aberration", "Type", "Details", "Drugs", "SupportEv")
      }
    } else {
      myTableDel <- data.frame()
    }
    
    
    # Supporting Evidence for Amplifications
    myTableAmp <- myTable[myTable$Type == "Amplification",]
    if(nrow(myTableAmp) > 0){
      myTableAmp <- merge(myTableAmp, rnaEvidence, by.x="Aberration", by.y="Gene", all.x=T)
      myTableAmp <- merge(myTableAmp, geneSetTS.sub, by.x="Aberration", by.y="values", all.x=T)
      myTableAmp <- myTableAmp[which(myTableAmp[,sampleInfo$subjectID]>100),]
      if(nrow(myTableAmp)>0) {
        myTableAmp[,"SupportEv"] <- paste("TPM=", myTableAmp[,sampleInfo$subjectID], ifelse(is.na(myTableAmp[,"ind"]), "", paste(", Pathway: ", myTableAmp[,"ind"], sep="")), sep="")
        myTableAmp <- myTableAmp[,c("Aberration", "Type", "Details", "Drugs", "SupportEv")]
      } else {
        colnames(myTableAmp) <- c("Aberration", "Type", "Details", "Drugs", "SupportEv")
      }
    } else {
      myTableAmp <- data.frame()
    }
    
    
    # Supporting Evidence for Mutations Oncogene - Expression is listed, Pathway is significant
    myTableMut <- myTable[myTable[,2]=="Mutation",]
    if(nrow(myTableMut) > 0){
      myTableMut[,"Gene"] <- sapply(myTableMut[,"Aberration"], FUN=getGeneFromMut)
      myTableMut <- merge(myTableMut, rnaEvidence, by.x="Gene", by.y="Gene", all.x=T)
      myTableMut <- merge(myTableMut, geneSetTS.sub, by.x="Gene", by.y="values", all.x=T)
      myTableMut[,"SupportEv"] <- paste("TPM=", myTableMut[,sampleInfo$subjectID], ifelse(is.na(myTableMut[,"ind"]), "", paste(", Pathway: ", myTableMut[,"ind"], sep="")), sep="")
      myTableMut <- myTableMut[,c("Aberration", "Type", "Details", "Drugs", "SupportEv")]
    } else {
      myTableMut <- data.frame()
    }
    
    
    # Supporting Evidence for Mutations Oncogene - Expression is listed, Pathway is significant
    myTableFus <- myTable[myTable[,2]=="Fusion",]
    if(nrow(myTableFus) > 0){
      myTableFus[,c("Gene1", "Gene2")] <- sapply(myTableFus[,"Aberration"], FUN=getGeneFromFus)
      myTableFus <- merge(myTableFus, rnaEvidence, by.x="Gene1", by.y="Gene", all.x=T)
      colnames(myTableFus)[colnames(myTableFus) == sampleInfo$subjectID] <- "Gene1_TPM"
      myTableFus <- merge(myTableFus, rnaEvidence, by.x="Gene2", by.y="Gene", all.x=T)
      colnames(myTableFus)[colnames(myTableFus) == sampleInfo$subjectID] <- "Gene2_TPM"
      myTableFus <- merge(myTableFus, geneSetTS.sub, by.x="Gene1", by.y="values", all.x=T)
      myTableFus <- merge(myTableFus, geneSetTS.sub, by.x="Gene2", by.y="values", all.x=T)
      myTableFus[,"SupportEv"] <- paste("TPM=", myTableFus[,"Gene1_TPM"],
                                        ", ",
                                        myTableFus[,"Gene2_TPM"],
                                        ifelse(is.na(myTableFus[,"ind.x"]), "", paste(", Pathway: ", myTableFus[,"ind.x"], ",", sep="")),
                                        ifelse(is.na(myTableFus[,"ind.y"]), "", paste("", myTableFus[,"ind.y"], sep="")), sep="")
      myTableFus <- myTableFus[,c("Aberration", "Type", "Details", "Drugs", "SupportEv")]
    } else {
      myTableFus <- data.frame()
    }
    
    myTable <- rbind(myTableAmp, myTableDel, myTableMut, myTableFus)
    myTable[,"SupportEv"] <- sapply(myTable[,"SupportEv"], FUN=remComma)
    colnames(myTable)[ncol(myTable)] <- "Supporting Evidence"
    myTable <- unique(myTable)
  } else {
    myTable <- data.frame()
  }
  
  # add Ensembl ids and map to targetvalidation.org
  myTable <- myTable %>%
    inner_join(expData %>% dplyr::select(gene_id, gene_symbol), by = c("Aberration" = "gene_symbol")) %>%
    mutate(TargetValidation = paste0('<a href = \"https://www.targetvalidation.org/target/',gene_id,'\">',gene_id,"</a>")) %>%
    dplyr::select(-c(gene_id))
  
  return(myTable)
}
