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
parser$add_argument("--public_phase", action = "store_true", help = "Public leaderborder phase")
parser$add_argument("-r", "--results", help = "Results path")
args <- parser$parse_args()

options(useFancyQuotes = FALSE) # ensure to encode single quotes properly

ncores <- 20
pred_dir <- "output"

invalid_reasons <- list()
neg_files <- c()
non_num_files <- c()
cells_files <- c()
genes_files <- c()

# read gs
all_gs <- readRDS(args$goldstandard_file)

# untar
if (is.null(args$submission_file)) {
  invalid_reasons <- append(
    invalid_reasons,
    sprintf("Expected FileEntity type but found %s", args$entity_type)
  )
} else {
  untar(args$submission_file)
}

# determine phase
if (args$public_phase) phase <- "public" else phase <- "private"

# retrieve all file names
basenames <- all_gs$down_basenames[[phase]]
true_pred_files <- paste0(basenames, "_imputed.csv")
pred_files <- list.files(pred_dir, pattern = "*_imputed.csv")

# validate if all required imputed files present
diff <- setdiff(true_pred_files, pred_files)
if (length(diff) > 0) {
  invalid_reasons <- append(
    invalid_reasons,
    paste0(
      length(diff), " file(s) not found : ",
      paste0(sQuote(diff), collapse = ", ") %>% stringr::str_trunc(250)
    )
  )
}

# iterate to validate each prediction file
if (length(diff) == 0) {
  parallel::mclapply(true_pred_files, function(pred_file) {
    pred_data <- data.table::fread(file.path(pred_dir, pred_file), verbose = FALSE) %>%
      tibble::column_to_rownames("V1")

    # validate if all data are non-negative
    if (any(pred_data < 0)) neg_files <<- append(neg_files, pred_file)

    # validate if all data are numeric
    if (any(!sapply(pred_data, is.numeric))) non_num_files <<- append(non_num_files, pred_file)

    # detect file prefix used to read gs
    info <- strsplit(pred_file, "_")[[1]]
    prefix <- info[1]

    gs_cells <- colnames(all_gs$gs_data[[prefix]])
    gs_genes <- rownames(all_gs$gs_data[[prefix]])

    # validate if minimumn shared cell/genes is matched
    n_shared_cells <- length(intersect(colnames(pred_data), gs_cells)) / length(gs_cells)
    n_shared_genes <- length(intersect(rownames(pred_data), gs_genes)) / length(gs_genes)
    if (n_shared_cells < 0.5) cells_files <<- append(cells_files, pred_file)
    if (n_shared_genes < 0.5) genes_files <<- append(genes_files, pred_file)
  }, mc.cores = ncores)

  # add invalid file names with specific reasons
  if (length(neg_files) > 0) {
    invalid_reasons <- append(
      invalid_reasons,
      paste0(
        "Not all values are numeric : ",
        paste0(sQuote(neg_files), collapse = ", ") %>% stringr::str_trunc(250)
      )
    )
  }

  if (length(non_num_files) > 0) {
    invalid_reasons <- append(
      invalid_reasons,
      paste0(
        "Negative value is not allowed : ",
        paste0(sQuote(non_num_files), collapse = ", ") %>% stringr::str_trunc(250)
      )
    )
  }

  if (length(cells_files) > 0) {
    invalid_reasons <- append(
      invalid_reasons,
      paste0(
        "Not enough matched cells (50%) are found : ",
        paste0(sQuote(cells_files), collapse = ", ") %>% stringr::str_trunc(250)
      )
    )
  }

  if (length(genes_files) > 0) {
    invalid_reasons <- append(
      invalid_reasons,
      paste0(
        "Not enough matched genes (50%) are found : ",
        paste0(sQuote(genes_files), collapse = ", ") %>% stringr::str_trunc(250)
      )
    )
  }
}

# add annotations
validate_status <- ifelse(length(invalid_reasons) > 0, "INVALID", "VALIDATED")
result <- list(
  submission_errors = paste0(invalid_reasons, collapse = "\n"),
  submission_status = validate_status
)
export_json <- jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)
