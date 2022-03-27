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
                     help = "Goldstandard file")
parser$add_argument("-c", "--condition", nargs = '+',
                    type = "character",
                    help = "Experiment condition")
parser$add_argument("-p", "--proportion", nargs = '+',
                    type = "character",
                    help = "Downsampling proportion")
parser$add_argument("-x", "--file_prefix",
                    type = "character",
                    help = "Prefix of filename")
parser$add_argument("-o", "--results",
                    type = "character",
                    help = "Results path")
args <- parser$parse_args()

## Decompress required data ------------------------------------
# decompress goldstandard file (tarball by default)
untar(args[["goldstandard"]])
# downsampled data and imputed data are parsed to wd via workflow

## Read all data ------------------------------------
# read conditions and downsampling props
exp_conditions <- args[["condition"]]
ds_props <- args[["proportion"]]
file_prefix <- args[["file_prefix"]]

## Note: Only work for sub-challenge 1 for now
## TODO: add metric for scATACseq
# read all downsampled data
all_down <- lapply(exp_conditions, function(c) {
  lapply(ds_props, function(p) {
    INPUT <- sprintf("%s_%s_%s.csv", file_prefix, c, p)
    df <- fread(INPUT, data.table = FALSE) %>% tibble::column_to_rownames("V1")
  }) %>% set_names(ds_props)
}) %>% set_names(exp_conditions)

# read all imputed data
all_imp <- lapply(exp_conditions, function(c) {
  lapply(ds_props, function(p) {
    INPUT <- sprintf("%s_%s_%s_imputed.csv", file_prefix, c, p)
    df <- fread(INPUT, data.table = FALSE) %>% tibble::column_to_rownames("V1")
  }) %>% set_names(ds_props)
}) %>% set_names(exp_conditions)

# create all goldstandard data
all_gs <- lapply(exp_conditions, function(c) {
  orig_10x <- Seurat::Read10X(file.path(c, "filtered_feature_bc_matrix"))
  # filter genes and columns that match the downsampled data
  filtered <- orig_10x[rownames(orig_10x) %in% rownames(all_down[[c]][[1]]), 
                       colnames(orig_10x) %in% colnames(all_down[[c]][[1]])]
}) %>% set_names(exp_conditions)


## Primary Metric: Characteristic Direction -----------------------------------
# the order of genes and cells names should be matched prior to this step
chdir_res <- sapply(exp_conditions, function(c) {
  sapply(ds_props, function(p) {
    getChdir(gs = all_gs[[c]],
             down = all_down[[c]][[p]],
             imp = all_imp[[c]][[p]])
  })
})

## Secondary Metric: NRMSE -----------------------------------
nrmse_res <- sapply(exp_conditions, function(c) {
  sapply(ds_props, function(p) {
    getNRMSE(gs = all_gs[[c]], imp = all_imp[[c]][[p]])
  })
})

## Write out the scores -----------------------------------
# create table to record all the individual scores
all_scores <- to_csv(chdir_res, 
                     nrmse_res, 
                     c("Characteristic Direction", "NRMSE"))
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

result_list <- list(chdir_breakdown = as.numeric(chdir_res),
                    chdir_avg_value = mean(unlist(chdir_res)),
                    nrmse_breakdown = as.numeric(nrmse_res),
                    nrmse_avg_value = mean(unlist(nrmse_res)),
                    submission_status = "SCORED")
export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)
