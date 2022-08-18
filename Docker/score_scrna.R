#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  library(argparse)
  library(parallel)
  library(data.table)
  library(tibble)
  library(purrr)
  library(dplyr)
  library(jsonlite)
  library(Seurat)
})

parser <- argparse::ArgumentParser()
parser$add_argument("-s", "--submission_file", help = "Submission file")
parser$add_argument("-g", "--goldstandard", help = "Goldstandard file")
parser$add_argument("-o", "--results", help = "Results path")
args <- parser$parse_args()

# load evaluation metrics
source("Docker/metrics.R")
ncores <- 16

# untar
untar(args$submission_file, exdir = "imp")

## Read all data ------------------------------------
# read the filenames of all downsampled data
imp_files <- list.files("imp", pattern = "*_imputed.csv")

# read ground truth data
all_gs <- readRDS(args$goldstandard)

# calculate scores each test case across different configurations
# for (c in conditions) {
all_scores <- mclapply(imp_files, function(imp_file) {
  print(paste0(c("Loading", imp_file, "..."), collapse = " "))

  # detect file prefix used to read gs
  info <- strsplit(imp_file, "_")[[1]]
  prefix <- info[1]
  condition <- info[2]

  # read prediction
  imp_path <- file.path("imp", imp_file)
  imp <- fread(imp_path, data.table = FALSE) %>% tibble::column_to_rownames("V1")
  imp <- NormalizeData(imp, verbose = FALSE)

  # read gs
  gs <- all_gs[[prefix]][[condition]]

  gs <- as.matrix(gs)
  imp <- as.matrix(imp)

  use_pseudobulk <- prefix %in% c("ds2", "ds3c")
  nrmse_score <- calculate_nrmse(gs, imp, pseudobulk = use_pseudobulk)
  spearman_score <- calculate_spearman(gs, imp, pseudobulk = use_pseudobulk)

  # collect scores for each test case
  score_table <- tibble(
    dataset = imp_file,
    nrmse_score = nrmse_score,
    spearman_score = spearman_score
  )
}, mc.cores = ncores) %>% bind_rows()

## Write out the scores -----------------------------------
# save scores table to record all the test cases
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# add annotations
result_list <- list(
  nrmse_average = mean(all_scores$nrmse_score),
  spearman_average = mean(all_scores$spearman_score),
  submission_status = "SCORED"
)
export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)