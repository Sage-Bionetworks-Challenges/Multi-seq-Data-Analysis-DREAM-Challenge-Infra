#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  library(argparse)
  library(parallel)
  library(data.table)
  library(tibble)
  library(dplyr)
  library(jsonlite)
  library(Seurat)
})

parser <- argparse::ArgumentParser()
parser$add_argument("-s", "--submission_file", help = "Submission file")
parser$add_argument("-g", "--goldstandard", help = "Goldstandard file")
parser$add_argument("--public_phase", action = "store_true", help = "Public leaderborder phase")
parser$add_argument("-o", "--results", help = "Results path")
args <- parser$parse_args()

# load evaluation metrics
source("/metrics.R")

ncores <- 15
pred_dir <- "output"
all_scores <- tibble()

# decompress
untar(args$submission_file)

## Read all data ------------------------------------
# read ground truth data
all_gs <- readRDS(args$goldstandard)

# read the filenames of all imputed data
basenames <- all_gs$down_basenames
# filter to subset data if it's public phase
if (args$public_phase) basenames <- basenames[grep("ds1_c3", basenames)]
true_pred_files <- paste0(basenames, "_imputed.csv")

# calculate scores each test case across different configurations
scores_df <- mclapply(true_pred_files, function(pred_file) {
  tryCatch(
    {
      # detect file prefix used to read gs
      info <- strsplit(pred_file, "_")[[1]]
      prefix <- info[1]
      condition <- info[2]

      # read prediction
      pred_path <- file.path(pred_dir, pred_file)
      pred_data <- fread(pred_path, data.table = FALSE, verbose = FALSE) %>% tibble::column_to_rownames("V1")
      pred_data <- NormalizeData(pred_data, verbose = FALSE)

      # read gs
      gs <- all_gs$gs_data[[prefix]][[condition]]

      eval_data <- .prepare(true = gs, pred = pred_data)

      # scoring
      use_pseudobulk <- prefix %in% c("ds2", "ds3c")
      nrmse_score <- calculate_nrmse(eval_data, pseudobulk = use_pseudobulk)
      spearman_score <- calculate_spearman(eval_data, pseudobulk = use_pseudobulk)

      # collect scores for each test case
      return(
        tibble(
          dataset = pred_file,
          primary_score = nrmse_score,
          secondary_score = abs(spearman_score)
        )
      )
    },
    error = function(e) {
      print(e$message)
    }
  )
}, mc.cores = ncores) %>% bind_rows()

all_scores <- rbind(all_scores, scores_df)

## Write out the scores -----------------------------------
# save scores table to record all the test cases
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# add annotations
result_list <- list(
  primary_average = mean(all_scores$primary_score, na.rm = TRUE),
  secondary_average = mean(all_scores$secondary_score, na.rm = TRUE),
  submission_status = "SCORED",
  submission_phase = ifelse(args$public_phase, "public", "private")
)

export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)
