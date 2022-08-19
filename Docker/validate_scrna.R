#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(argparse)
  library(data.table)
  library(tibble)
  library(jsonlite)
})

parser <- argparse::ArgumentParser()
parser$add_argument("-s", "--submission_file", help = "Submission file")
parser$add_argument("-e", "--entity_type", help = "synapse entity type downloaded")
parser$add_argument("-i", "--input_file", help = "Input file of downsampled data")
parser$add_argument("-o", "--results", help = "Results path")
args <- parser$parse_args()

invalid_reasons <- list()

# untar
untar(args$input_file, exdir = "down")
if (is.null(args$submission_file)) {
  invalid_reasons <- append(
    invalid_reasons,
    sprintf("Expected FileEntity type but found %s", args$entity_type)
  )
} else {
  untar(args$submission_file, exdir = "imp")
}

# retrieve all file names
down_files <- list.files("down", pattern = "*.csv")
true_imp_files <- paste0(tools::file_path_sans_ext(down_files), "_imputed.csv")
imp_files <- list.files("imp", pattern = "*.csv")

# validate if all required imputed files present
diff <- setdiff(true_imp_files, imp_files)
if (length(diff) > 0) {
  invalid_reasons <- append(
    invalid_reasons,
    paste0(
      "File not found : ",
      paste0(sQuote(diff), collapse = ", ")
    )
  )
}

# iterate to validate each prediction file
invisible(
  lapply(seq_along(down_files), function(i) {
    imp <- data.table::fread(file.path("imp", true_imp_files[i])) %>%
      tibble::column_to_rownames("V1")

    # validate if all data are non-negative
    if (any(imp < 0)) {
      invalid_reasons <<- append(
        invalid_reasons,
        paste0(imp_file, " : Negative value is not allowed")
      )
    }

    # validate if all data are numeric
    if (any(!sapply(imp, is.numeric))) {
      invalid_reasons <<- append(
        invalid_reasons,
        paste0(imp_file, " : Not all values are numeric")
      )
    }

    down <- data.table::fread(file.path("down", down_files[i])) %>%
      tibble::column_to_rownames("V1")

    # validate if all cells are matched
    if (setequal(colnames(down), colnames(imp))) {
      invalid_reasons <<- append(
        invalid_reasons,
        paste0(imp_file, " : Do not contain all the cells or unknown cells found")
      )
    }

    # validate if all genes are matched
    if (any(!rownames(down) %in% rownames(imp))) {
      invalid_reasons <<- append(
        invalid_reasons,
        paste0(imp_file, " : Do not contain all the genes")
      )
    }
  })
)

# add annotations
validate_status <- ifelse(length(invalid_reasons) > 0, "INVALID", "VALIDATED")
result <- list(
  submission_errors = paste0(invalid_reasons, collapse = "\n"),
  submission_status = validate_status
)
export_json <- jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)