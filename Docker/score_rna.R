#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  library(argparse)
  library(data.table)
  library(dplyr)
  library(purrr)
})

# use all available cores
ncores <- parallel::detectCores()

# load evaluation metrics
source("/metrics.R")
# load utils function
reticulate::source_python("/utils.py")

# load all args
parser <- argparse::ArgumentParser()
parser$add_argument("-g", "--goldstandard",
  type = "character",
  help = "Goldstandard file"
)
parser$add_argument("-s", "--submission_file",
  type = "character",
  help = "Submission file"
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
# decompress goldstandard file
untar(args[["goldstandard"]])
decompress_file(args[["submission_file"]])

# downsampled data and imputed data are parsed to wd via workflow

## Read read conditions and downsampling props ------------------------------------
input_info <- jsonlite::read_json(args[["config_json"]])
input_info <- input_info$scRNAseq

## Calculate scores ------------------------------------

all_scores <- tibble()

for (info in input_info) {
  # set up configuration
  prefix <- info$dataset
  conditions <- unlist(info$conditions)
  ds_props <- unlist(info$props)
  replicates <- 1:info$replicates

  # pre-load raw data once
  if (prefix == "ds1") {
    orig_10x <- lapply(conditions, function(c) {
      Seurat::Read10X(file.path(prefix, c, "filtered_feature_bc_matrix"))
    }) %>% set_names(conditions)
  } else {
    suppressMessages(orig_10x <- Seurat::Read10X(file.path(prefix, "filtered_feature_bc_matrix"))$`Gene Expression`)
  }

  # calculate scores each test case across different configurations
  for (c in conditions) {
    for (p in ds_props) {
      score_table <- parallel::mclapply(replicates, function(n) {
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
        return(
          tibble(
            dataset = prefix,
            condition = c,
            proportion = p,
            replicate = n,
            nrmse_score = primary_score,
            spearman_score = secondary_score
          )
        )
      }, mc.cores = ncores)

      all_scores <- bind_rows(all_scores, score_table)
    }
  }
}

## Write out the scores -----------------------------------
# save scores table to record all the test cases
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# add annotations
result_list <- list(
  primary_average = mean(all_scores$nrmse_score),
  secondary_average = mean(all_scores$spearman_score),
  submission_status = "SCORED"
)
export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)