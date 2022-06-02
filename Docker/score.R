#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  library(argparse)
  library(data.table)
  library(dplyr)
})

# get available cores
ncores <- parallel::detectCores()

# load evaluation metrics
source("/metrics.R")

# load all args
parser <- argparse::ArgumentParser()
parser$add_argument("-g", "--goldstandard",
  type = "character",
  help = "Goldstandard file"
)
parser$add_argument("-c", "--config_json",
  type = "character",
  help = "Input information json file"
)
parser$add_argument("-o", "--results",
  type = "character",
  help = "Results path"
)
args <- parser$parse_args()

## Decompress required data ------------------------------------
# decompress goldstandard file (tarball by default)
untar(args[["goldstandard"]])
# downsampled data and imputed data are parsed to wd via workflow

## Read read conditions and downsampling props ------------------------------------
input_info <- jsonlite::read_json(args[["config_json"]])
input_info <- input_info$scRNAseq

## Calculate scores ------------------------------------

# add variables that will be saved for results
all_primary_scores <- c()
all_secondary_scores <- c()
all_datasets <- c()
all_conditions <- c()
all_props <- c()
all_replicates <- c()

for (info in input_info) {
  # set up configuration
  prefix <- info$dataset
  conditions <- unlist(info$conditions)
  ds_props <- unlist(info$props)
  replicates <- 1:info$replicates

  # pre-load raw data once
  if (prefix == "ds1") {
    orig_10x <- lapply(conditions, function(c) {
      Seurat::Read10X(file.path("dataset1", c, "filtered_feature_bc_matrix"))
    }) %>% set_names(conditions)
  } else {
    suppressMessages(orig_10x <- Seurat::Read10X(file.path(prefix, "filtered_feature_bc_matrix"))$`Gene Expression`)
  }

  # calculate scores each test case across different configurations
  for (c in conditions) {
    for (p in ds_props) {
      invisible(
        mclapply(replicates, function(n) {
          # read imputed data
          imp_path <- sprintf("%s_%s_%s_%s_imputed.csv", prefix, c, p, n)
          imp <- fread(imp_path, data.table = FALSE) %>% tibble::column_to_rownames("V1")

          # filter genes (and cells) of raw data that match the imputed data for scoring
          if (prefix == "ds1") {
            gs <- orig_10x[[c]][rownames(imp), colnames(imp)]
          } else {
            gs <- orig_10x[rownames(imp), ]
          }

          primary_score <- calculate_nrmse(gs, imp, pseudobulk = prefix != "ds1")
          secondary_score <- calculate_spearman(gs, imp, pseudobulk = prefix != "ds1")

          # collect configuration info for each test case
          all_primary_scores <<- c(all_primary_scores, primary_score)
          all_secondary_scores <<- c(all_secondary_scores, secondary_score)
          all_datasets <<- c(all_datasets, prefix)
          all_conditions <<- c(all_conditions, c)
          all_props <<- c(all_props, p)
          all_replicates <<- c(all_replicates, n)
        }, mc.cores = ncores)
      )
    }
  }
}

## Write out the scores -----------------------------------
# save scores table to record all the test cases
all_scores <- data.frame(
  dataset = all_datasets,
  condition = all_conditions,
  proportion = all_props,
  replicate = all_replicates,
  nrmse_score = all_primary_scores,
  spearman_score = all_secondary_scores
)
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# add annotations
result_list <- list(
  primary_breakdown = all_primary_scores,
  secondary_breakdown = all_secondary_scores,
  primary_average = mean(all_primary_scores),
  secondary_average = mean(all_secondary_scores),
  submission_status = "SCORED"
)
export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)