#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  library(argparse)
  library(data.table)
  library(tibble)
  library(purrr)
  library(dplyr)
  library(jsonlite)
  library(GeoDE)
  library(Seurat)
})

# load evaluation metrics
source("/metrics.R")

# load all args
parser <- argparse::ArgumentParser()
parser$add_argument("-g", "--goldstandard",
  type = "character",
  help = "Goldstandard file"
)
parser$add_argument("-j", "--input_json",
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
input_info <- jsonlite::read_json(args[["input_json"]])
input_info <- input_info$scRNAseq

## Calculate scores ------------------------------------

# add variables that will be saved for results
all_pri_scores <- c()
all_sec_scores <- c()
all_datasets <- c()
all_conditions <- c()
all_props <- c()


for (info in input_info) {
  # read conditions and downsampling props
  prefix <- info$dataset
  conditions <- unlist(info$conditions)
  ds_props <- unlist(info$props)

  # pre-load raw data
  if (prefix == "dataset1") {
    orig_10x <- lapply(conditions, function(c) {
      Seurat::Read10X(file.path("dataset1", c, "filtered_feature_bc_matrix"))
    }) %>% set_names(conditions)
  } else {
    suppressMessages(
      orig_10x <- Seurat::Read10X(file.path(prefix, "filtered_feature_bc_matrix"))
    )
    orig_10x <- orig_10x$`Gene Expression`
  }

  # read all downsampled data
  for (c in conditions) {
    for (p in ds_props) {
      # read downsampled data
      down_path <- sprintf("%s_%s_%s.csv", prefix, c, p)
      down <- fread(down_path, data.table = FALSE) %>% tibble::column_to_rownames("V1")

      # read imputed data
      imp_path <- sprintf("%s_%s_%s_imputed.csv", prefix, c, p)
      imp <- fread(imp_path, data.table = FALSE) %>% tibble::column_to_rownames("V1")

      # get goldstandard data
      # filter genes that match the downsampled data
      if (prefix == "dataset1") {
        gs <- orig_10x[[c]][rownames(down), colnames(down)]
      } else {
        gs <- orig_10x[rownames(down), ]
      }

      score1 <- getChdir(gs = gs, down = down, imp = imp, pseudo = prefix != "dataset1")
      score2 <- getNRMSE(gs = gs, imp = imp, pseudo = prefix != "dataset1")

      all_pri_scores <- c(all_pri_scores, score1)
      all_sec_scores <- c(all_sec_scores, score2)
      all_datasets <- c(all_datasets, prefix)
      all_conditions <- c(all_conditions, c)
      all_props <- c(all_props, p)
    }
  }
}

## Write out the scores -----------------------------------
# create table to record all the individual scores
all_scores <- data.frame(
  dataset = all_datasets,
  condition = all_conditions,
  downsampled_prop = all_props,
  chdir_score = all_pri_scores,
  nrmse_score = all_sec_scores
)
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# create annotations
result_list <- list(
  chdir_breakdown = all_pri_scores,
  nrmse_breakdown = all_sec_scores,
  submission_status = "SCORED"
)
export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)