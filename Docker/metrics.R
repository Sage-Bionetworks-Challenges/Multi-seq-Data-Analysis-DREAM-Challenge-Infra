## Function to calculate scores on scRNAseq data ------------------
.prepare <- function(true, pred, pseudobulk = FALSE, proportion = NULL) {
  shared_cells <- intersect(colnames(pred), colnames(true))
  shared_genes <- intersect(rownames(pred), rownames(true))

  # number of missing cells and genes
  if (pseudobulk) {
    stopifnot(!is.null(proportion))
    proportion <- as.numeric(gsub("p0", "0.", proportion)) # i.e, 'p025' -> 0.25
    # using pseudobulk means the cells of training data are subsetted
    # calculate expected number of cells
    total_cells <- floor(ncol(true) * proportion)
    n_na_cells <- total_cells - length(shared_cells)
  } else {
    n_na_cells <- sum(!colnames(true) %in% colnames(pred))
    total_cells <- ncol(true)
  }
  n_na_genes <- sum(!rownames(true) %in% rownames(pred))
  total_genes <- nrow(true)

  # match the orders of genes and cells
  if (pseudobulk) {
    out_true <- as.matrix(true[shared_genes, ])
    out_pred <- as.matrix(pred[shared_genes, ])
  } else {
    out_true <- as.matrix(true[shared_genes, shared_cells])
    out_pred <- as.matrix(pred[shared_genes, shared_cells])
  }
  return(list(
    true = out_true,
    pred = out_pred,
    n_na_cells = n_na_cells,
    n_na_genes = n_na_genes,
    total_cells = total_cells,
    total_genes = total_genes
  ))
}

calculate_nrmse <- function(.data, pseudobulk = FALSE) {
  true <- .data$true
  pred <- .data$pred
  n_na_genes <- .data$n_na_genes
  n_na_cells <- .data$n_na_cells
  total_cells <- .data$total_cells

  if (pseudobulk) {
    true_rs <- rowSums(true)
    pred_rs <- rowSums(pred)
    rmse <- sqrt(mean((true_rs - pred_rs)**2))
    if (n_na_genes > 0) rmse <- c(rmse, rep(1, n_na_genes))
    if (n_na_cells > 0) rmse <- rmse / (1 - n_na_cells / total_cells)
    nrmse <- rmse / (max(true_rs) - min(true_rs))
  } else {
    rmse <- sqrt(rowMeans((true - pred)**2))
    if (n_na_genes > 0) rmse <- c(rmse, rep(1, n_na_genes))
    if (n_na_cells > 0) rmse <- rmse / (1 - n_na_cells / total_cells)
    range_rr <- matrixStats::rowMaxs(true) - matrixStats::rowMins(true)
    nrmse <- rmse / range_rr
  }

  score <- mean(nrmse)

  return(score)
}

calculate_spearman <- function(.data, pseudobulk = FALSE, na.rm = TRUE) {
  true <- .data$true
  pred <- .data$pred
  n_na_genes <- .data$n_na_genes
  n_na_cells <- .data$n_na_cells
  total_cells <- .data$total_cells

  if (pseudobulk) {
    true_rs <- rowSums(true)
    pred_rs <- rowSums(pred)
    spearman <- cor(true_rs, pred_rs, method = "spearman")
    if (n_na_genes > 0) spearman <- c(spearman, rep(0, n_na_genes))
  } else {
    spearman <- sapply(1:nrow(true), function(i) cor(true[i, ], pred[i, ], method = "spearman"))
    if (n_na_genes > 0) spearman <- c(spearman, rep(0, n_na_genes))
  }

  score <- mean(spearman, na.rm = na.rm)
  if (n_na_cells > 0) score <- score * (1 - n_na_cells / total_cells)

  return(score)
}

## Function to calculate scores on scATACseq data ------------------
# correct the bed
correct_peaks <- function(bed_data) {
  peak_data <- bed_data[, 1:3]
  bp <- peak_data[, 3] - peak_data[, 2]
  if (!all(bp == 1)) {
    # choose middle point as summit if summit is not reported
    summit <- floor((peak_data[, 2] + peak_data[, 3]) / 2)
    peak_data[, 2] <- summit
    peak_data[, 3] <- summit + 1
  }

  return(peak_data)
}

# pad the peaks
pad_peaks <- function(peak_data, genome, padding = 150) {

  # correct the bed file
  colnames(peak_data)[1:3] <- c("chr", "start", "end")

  summit <- peak_data$start
  chr_ranges <- lapply(unique(peak_data$chr), function(chr) {
    list(
      chr = chr,
      start = start(genome[[chr]])[1],
      end = end(genome[[chr]])[1]
    )
  }) %>% rbindlist()

  # add padding using vectorized method to speed up runtime
  new_start_loc <- pmax(summit - padding, chr_ranges$start[match(peak_data$chr, chr_ranges$chr)])
  new_end_loc <- pmin(summit + padding, chr_ranges$end[match(peak_data$chr, chr_ranges$chr)])

  new_peak_data <- data.frame(
    chr = peak_data$chr,
    start = new_start_loc,
    end = new_end_loc
  )

  return(new_peak_data)
}

# load evaluation metrics
category_recall <- function(a, b, verbose = FALSE) {
  a.int2 <- tryCatch(
    {
      bedr(input = list(a = a, b = b), method = "intersect -u", params = "-sorted", verbose = verbose)
    },
    error = function(cond) {
      return(data.frame())
    } # return empty df on error
  )
  # fraction of rows in ground truth that overlap at all with peaks in submission
  return(nrow(a.int2) / nrow(a))
}
