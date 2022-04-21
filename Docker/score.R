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
source("../Docker/metrics.R")

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
chdir_scores <- c()
nrmse_scores <- c()
test_names <- c()
# read all downsampled data
# for (info in input_info) {
info <- input_info[[2]] # test dataset2 only
# read conditions and downsampling props
prefix <- info$dataset
exp_conditions <- unlist(info$conditions)
ds_props <- unlist(info$props)

# read all downsampled data
for (c in exp_conditions) {
  for (p in ds_props) {
    # read downsampled data
    down_path <- sprintf("%s_%s_%s.csv", prefix, c, p)
    down <- fread(down_path, data.table = FALSE) %>% tibble::column_to_rownames("V1")

    # read imputed data
    imp_path <- sprintf("%s_%s_%s_imputed.csv", prefix, c, p)
    imp <- fread(imp_path, data.table = FALSE) %>% tibble::column_to_rownames("V1")

    if (!exists("gs")) {
      # read raw data
      if (prefix == "dataset1") {
        orig_10x <- Seurat::Read10X(file.path(prefix, c, "filtered_feature_bc_matrix"))
      } else {
        orig_10x <- Seurat::Read10X(file.path(prefix, "filtered_feature_bc_matrix"))
        orig_10x <- orig_10x$`Gene Expression`
      }
      # get goldstandard data
      # filter genes that match the downsampled data
      gs <- orig_10x[rownames(down), ]
    }

    score1 <- getChdir(gs = gs, down = down, imp = imp)
    score2 <- getNRMSE(gs = gs, imp = imp)
    chdir_scores <- c(chdir_scores, score1)
    nrmse_scores <- c(nrmse_scores, score2)
    test_names <- c(test_names, paste(c(prefix, c, p), collapse = "-"))
  }
  rm("gs") # remove every new condition finishes
}
# }

## Write out the scores -----------------------------------
# create table to record all the individual scores
test_names <- strsplit(test_names, "-")
all_scores <- data.frame(
  dataset = sapply(test_names, `[[`, 1),
  condition = sapply(test_names, `[[`, 2),
  downsampled_prop = sapply(test_names, `[[`, 3),
  chdir_score = chdir_res,
  nrmse_score = nrmse_res
)
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# create annotations
result_list <- list(
  chdir_breakdown = chdir_res,
  chdir_avg_value = mean(chdir_res),
  nrmse_breakdown = nrmse_res,
  nrmse_avg_value = mean(nrmse_res),
  submission_status = "SCORED"
)
export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)