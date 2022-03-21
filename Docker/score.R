#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  # all packages are installed from cran
  library(argparse)
  library(data.table)
  library(tibble)
  library(purrr)
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
parser$add_argument("-s", "--submission_file",
                    type = "character",
                    help = "Submission file")
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

# decompress submission file
if (endsWith(args[["submission_file"]], ".tar.gz")) {
  system(sprintf("tar zxvf %s --strip-components=1", args[["submission_file"]]))
} else if (endsWith(args[["submission_file"]], ".zip")) {
  unzip(args[["submission_file"]], junkpaths = TRUE)
} else {
  stop(args[["submission_file"]], " is not compressed as .zip or .tar.gz")
}

## Read all data ------------------------------------
# read conditions and downsampling props
exp_conditions <- args[["condition"]]
ds_props <- args[["proportion"]]
file_prefix <- args[["file_prefix"]]

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
test_names <- printScore(sapply(exp_conditions, FUN = paste0, "+", ds_props))
result_list <- list(breakdown_test_name = test_names,
                    primary_metric = "Characteristic Direction",
                    primary_metric_breakdown = printScore(chdir_res),
                    secondary_metric = "NRMSE",
                    secondary_metric_breakdown = printScore(nrmse_res),
                    submission_status = "SCORED")
export_json <- toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)
