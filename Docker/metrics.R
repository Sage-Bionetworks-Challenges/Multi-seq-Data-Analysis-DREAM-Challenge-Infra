# .filter_zip <- function(zip_file, pattern) {
#   stopifnot(tools::file_ext(zip_file) == "zip")
#   suppressWarnings(files_list <- unzip(zip_file, list = TRUE))
#   clean_list <- files_list[grep(pattern, files_list)]
#   return(clean_list)
# }

# .filter_tar <- function(tar_file, pattern) {
#   stopifnot(grepl("^.*.tar.gz$", tar_file))
#   suppressWarnings(files_list <- untar(tar_file, list = TRUE))
#   clean_list <- files_list[grep(pattern, files_list)]
#   return(clean_list)
# }

# #' Decompress all the files
# #' @param archive Compressed archive file with either .zip or .tar.gz extension (other extensions will not be accepted).
# #'
# extract_files <- function(archive, pattern = NULL, outdir = ".") {
#   stopifnot(grepl("^.*.(zip|tar.gz)$", archive))
#   dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
#   files_list <- NULL

#   if (tools::file_ext(archive) == "zip") {
#     if (!is.null(pattern)) files_list <- .filter_zip(archive, pattern)
#     unzip(archive, files = files_list, exdir = outdir)
#   } else {
#     if (!is.null(pattern)) files_list <- .filter_tar(archive, pattern)

#     system(
#       paste(collapse = " ", c(
#         "tar -xf", archive,
#         "-C", outdir,
#         if (length(files_list) > 0) c("-z", files_list)
#       ))
#     )
#   }
# }

## general function to calcualte NRMSE scores  ------------------
nrmse <- function(true, pred, norm = "range") {
  true <- as.numeric(true)
  pred <- as.numeric(pred)

  rmse <- sqrt(mean((true - pred)**2))
  # only support normalizing by range for now
  if (norm == "range") {
    out <- rmse / (max(true) - min(pred))
  }

  return(out)
}

## General function to calculate spearman correlation scores ------------------
spearman <- function(true, pred) {
  true <- as.numeric(true)
  pred <- as.numeric(pred)

  out <- cor(true, pred, method = "spearman")

  return(out)
}


## Function to calculate NRMSE scores on scRNAseq data ------------------
calculate_nrmse <- function(gs, imp, pseudobulk = FALSE) {
  gs <- as.matrix(gs)
  imp <- as.matrix(imp)

  if (pseudobulk) {
    gs <- rowSums(gs)
    imp <- rowSums(imp)
    nrmse_res <- nrmse(gs, imp)
  } else {
    nrmse_res <- sapply(1:nrow(gs), function(i) nrmse(gs[i, ] - imp[i, ]))
  }

  # use average nrmse values across all genes as final score
  score <- mean(nrmse_res)

  return(score)
}

## Function to calculate spearman scores on scRNAseq data ------------------
calculate_spearman <- function(gs, imp, pseudobulk = FALSE, na.rm = TRUE) {
  gs <- as.matrix(gs)
  imp <- as.matrix(imp)

  if (pseudobulk) {
    gs <- rowSums(gs)
    imp <- rowSums(imp)
    cor_res <- spearman(gs, imp)
  } else {
    cor_res <- sapply(1:nrow(gs), function(i) spearman(gs[i, ] - imp[i, ]))
  }

  score <- mean(cor_res, na.rm = na.rm)

  return(score)
}