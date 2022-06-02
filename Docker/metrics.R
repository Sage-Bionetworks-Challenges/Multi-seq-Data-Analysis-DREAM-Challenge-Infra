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
  if (pseudobulk) {
    gs <- rowSums(gs)
    imp <- rowSums(imp)
    nrmse_res <- nrmse(gs, imp)
  } else {
    gs <- as.matrix(gs)
    imp <- as.matrix(imp)
    nrmse_res <- sapply(1:nrow(gs), function(i) nrmse(gs[i, ] - imp[i, ]))
  }

  # use average nrmse values across all genes as final score
  score <- mean(nrmse_res)

  return(score)
}

## Function to calculate spearman scores on scRNAseq data ------------------
calculate_spearman <- function(gs, imp, pseudobulk = FALSE, na.rm = TRUE) {
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