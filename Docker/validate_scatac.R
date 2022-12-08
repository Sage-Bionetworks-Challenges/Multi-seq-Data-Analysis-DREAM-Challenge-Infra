#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(argparse)
  library(data.table)
  library(tibble)
  library(jsonlite)
})

# read arguments
parser <- argparse::ArgumentParser()
parser$add_argument("-g", "--goldstandard_file", help = "Goldstandard file")
parser$add_argument("-s", "--submission_file", help = "Submission file")
parser$add_argument("-e", "--entity_type", help = "Synapse entity type downloaded")
parser$add_argument("--public_phase", help = "Public leaderborder phase")
parser$add_argument("-r", "--results", help = "Results path")
args <- parser$parse_args()

options(useFancyQuotes = FALSE) # ensure to encode single quotes properly

pred_dir <- "output"

invalid_reasons <- list()
neg_files <- c()
col_type_files <- c()
col_n_files <- c()

# read gs
all_gs <- readRDS(args$goldstandard_file)

# decompress
if (is.null(args$submission_file)) {
  invalid_reasons <- append(
    invalid_reasons,
    sprintf("Expected FileEntity type but found %s", args$entity_type)
  )
} else {
  untar(args$submission_file)
}

# determine phase
phase <- args$public_phase

# retrieve all file names
basenames <- all_gs$down_basenames[[phase]]
true_pred_files <- paste0(basenames, ".bed")
pred_files <- list.files(pred_dir, pattern = "*.bed")

# validate if all required imputed files present
diff <- setdiff(true_pred_files, pred_files)
if (length(diff) > 0) {
  invalid_reasons <- append(
    invalid_reasons,
    paste0(
      length(diff), " file not found : ",
      paste0(sQuote(diff), collapse = ", ") %>% stringr::str_trunc(80)
    )
  )
}

# iterate to validate each prediction file
if (length(diff) == 0) {
  res <- lapply(true_pred_files, function(pred_file) {
    pred_data <- data.table::fread(file.path(pred_dir, pred_file))

    # validate if there are at least three columns used for evaluations
    if (any(ncol(pred_data < 3))) col_n_files <<- append(col_n_files, pred_data)

    # validate if first three columns follows right tyep
    # try not to limit to only int for now (numeric could be int or float in r)
    if (!is.character(pred_data[, 1]) || any(!sapply(pred_data[, 2:3], is.numeric))) col_type_files <<- append(col_type_files, pred_data)

    # validate if all data are non-negative
    if (any(pred_data[, 2:3] < 0)) neg_files <<- append(neg_files, pred_data)
  })

  # add invalid file names with specific reasons
  if (length(col_n_files) > 0) {
    invalid_reasons <- append(
      invalid_reasons,
      paste0(
        "The called peak file should have at least three columns ('chr', 'start', 'stop') : ",
        paste0(sQuote(col_n_files), collapse = ", ") %>% stringr::str_trunc(160)
      )
    )
  }

  if (length(col_type_files) > 0) {
    invalid_reasons <- append(
      invalid_reasons,
      paste0(
        "Types of columns are not matched, please make sure the types of first three columns are 'string', 'numeric' and 'numeric' : ",
        paste0(sQuote(col_n_files), collapse = ", ") %>% stringr::str_trunc(160)
      )
    )
  }

  if (length(neg_files) > 0) {
    invalid_reasons <- append(
      invalid_reasons,
      paste0(
        "Not all values are numeric : ",
        paste0(sQuote(neg_files), collapse = ", ") %>% stringr::str_trunc(80)
      )
    )
  }
}

# add status
validate_status <- ifelse(length(invalid_reasons) > 0, "INVALID", "VALIDATED")
result <- list(
  submission_errors = paste0(invalid_reasons, collapse = "\n"),
  submission_status = validate_status
)
export_json <- jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)
