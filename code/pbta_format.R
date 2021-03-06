#####################
# Format PBTA data
#####################

# PBTA clinical
pbta.clinData <- pbta.clinData %>%
  filter(experimental_strategy == "RNA-Seq") %>%
  mutate(sample_barcode = Kids_First_Biospecimen_ID,
         study_id = "PBTA",
         library_name = RNA_library) %>%
  dplyr::select(sample_barcode, sample_id, reported_gender, age_at_diagnosis_days, ethnicity, pathology_diagnosis, integrated_diagnosis, short_histology, broad_histology, primary_site, study_id, library_name)

# PNOC008 clinical 
# merge with PBTA clinical
pat.clinData <- pnoc008.clinData[,c(rep('subjectID', 2), 'sex', 'age_diagnosis_days', 'ethnicity', rep('tumorType', 4), 'tumorLocation', 'study_id', 'library_name')] 
colnames(pat.clinData) <- colnames(pbta.clinData)
pbta.clinData <- rbind(pbta.clinData, pat.clinData)
rownames(pbta.clinData) <- pbta.clinData$sample_barcode

# Combine PBTA and PNOC Patients expression matrix
combGenes <- intersect(rownames(pbta.mat), rownames(pnoc008.data))
pbta.mat <- cbind(pbta.mat[combGenes,], pnoc008.data[combGenes,])
pbta.mat <- pbta.mat[,rownames(pbta.clinData)]

# Correct for batch effect: study_id + library_name
pbta.clinData$batch <- paste0(pbta.clinData$study_id,'_', pbta.clinData$library_name)
if(snv_pattern != "lancet" & file.exists('data/Reference/PBTA/pbta_pnoc008_corrected_matrix.rds')){
  pbta.mat <- readRDS('data/Reference/PBTA/pbta_pnoc008_corrected_matrix.rds')
} else {
  pbta.mat <- quiet(batch.correct(mat = pbta.mat, clin = pbta.clinData))
  saveRDS(pbta.mat, file = 'data/Reference/PBTA/pbta_pnoc008_corrected_matrix.rds')
}

# keep full matrix for ImmuneProfile.R (only PBTA + PNOC patient of interest)
pbta.mat.full <- pbta.mat 
smps <- grep('BS_', colnames(pbta.mat.full), value = T)
smps <- c(smps, sampleInfo$subjectID)
pbta.mat.all <- pbta.mat.full[,colnames(pbta.mat.full) %in% smps]

# Now remove genes that have max value < 20 TPM
maxVals <- apply(pbta.mat, FUN = max, MARGIN = 1)
pbta.mat <- pbta.mat[maxVals>20,]

# Order samples for expression and clinical file
common.smps <- intersect(colnames(pbta.mat), rownames(pbta.clinData))
pbta.mat <- pbta.mat[,common.smps]
pbta.clinData <- pbta.clinData[common.smps,]

###########################
# Get Annotation data ready 
# Constrain columns
##########################

# for getTSNEPlot.R
# Get top 10000 most variable genes
myCV <- function(x) { sd(x)/mean(x)}
myCVs <- apply(pbta.mat, FUN = myCV, MARGIN=1)
pbta.mat.tsne <- as.data.frame(pbta.mat)
pbta.mat.tsne$CV <- myCVs
pbta.mat.tsne <- pbta.mat.tsne[order(pbta.mat.tsne$CV, decreasing = TRUE),]
if(nrow(pbta.mat.tsne) >= 10000){
  pbta.mat.tsne <- pbta.mat.tsne[1:10000,]
}
pbta.mat.tsne$CV <- NULL # Remove cv

# for clustering
# use UMAP correlation
pbta.umap.output <- file.path(topDir, 'Summary/pbta_pnoc008_umap_output.rds')
if(file.exists(pbta.umap.output)){
  pbta.umap <- readRDS(file = pbta.umap.output)
} else {
  set.seed(100)
  pbta.umap <- uwot::umap(X = t(log2(pbta.mat.tsne+1)), n_neighbors = 21, n_components = 2, metric = "correlation", ret_nn = TRUE, n_sgd_threads = 123L)
  saveRDS(pbta.umap, file = pbta.umap.output)
}
pbta.embedding <- as.data.frame(pbta.umap$embedding)
colnames(pbta.embedding) <- c("UMAP1", "UMAP2")

# for getKMPlot.R and getSimilarPatients.R
# extract nearest neighbor info
corr <- as.data.frame(pbta.umap$nn$correlation$idx) # nn
dist <- as.data.frame(pbta.umap$nn$correlation$dist) # distances
corr <- t(apply(corr, MARGIN = 1, FUN = function(x) colnames(pbta.mat.tsne)[x]))
rownames(corr) <- colnames(pbta.mat.tsne)
rownames(dist) <- colnames(pbta.mat.tsne)
pbta_nn_table <- data.frame(nearest_neighbor = as.character(corr[grep(sampleInfo$subjectID, rownames(corr)),]), 
                       distance = as.numeric(dist[grep(sampleInfo$subjectID, rownames(dist)),]))
pbta_nn_table$distance <- round(pbta_nn_table$distance, digits = 3)
pbta.allCor <- pbta_nn_table[grep(sampleInfo$subjectID, pbta_nn_table$nearest_neighbor, invert = TRUE),]

# Immune profile, ssGSEA, recurrent alterations (keep POI)
pbta.topCor <- pbta.mat.full[,colnames(pbta.mat.full) %in% pbta_nn_table$nearest_neighbor]

# # for getKMPlot.R and getSimilarPatients.R
# pbta.allCor <- cor(x = pbta.mat.tsne[sampleInfo$subjectID], y = pbta.mat.tsne)
# pbta.allCor <- data.frame(t(pbta.allCor), check.names = F)
# pbta.allCor[,"sample_barcode"] <- rownames(pbta.allCor)
# pbta.allCor <- pbta.allCor[!grepl(sampleInfo$subjectID, rownames(pbta.allCor)),]
# pbta.allCor <- pbta.allCor[order(pbta.allCor[,1], decreasing = TRUE),]
# pbta.allCor[,1] <- round(pbta.allCor[,1], 3)
# 
# # get matrix of top 20 correlated samples (for Immune profile of genomically similar patients)
# pbta.topCor <- pbta.allCor[1:20,'sample_barcode']
# pbta.topCor <- c(pbta.topCor, sampleInfo$subjectID) # add patient of interest
# pbta.topCor <- pbta.mat.full[,colnames(pbta.mat.full) %in% pbta.topCor]
