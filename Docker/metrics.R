
### Characteristic Direction
getAngle <- function(a = NULL, b = NULL) {
  theta <- acos(
    sum(a * b) / (sqrt(sum(a * a)) * sqrt(sum(b * b)))
  )
  return(theta)
}

### lsa Cosine
getCosine <- function(gs, down, imp) {
  v0 <- rowSums(gs)
  v1 <- rowSums(down)
  v2 <- rowSums(imp)

  angle <- lsa::cosine(v0 - v1, v2 - v1)
  return(angle)
}

getChdir <- function(gs = NULL, down = NULL, imp = NULL, pseudobulk = FALSE) {
  if (pseudobulk) {
    angle <- getCosine(gs, down, imp)
  } else {
    XY <- cbind(genenames = rownames(gs), gs, down)
    YZ <- cbind(genenames = rownames(down), down, imp)
    condition <- as.factor(rep(c(1, 2), each = ncol(gs)))

    XY$genenames <- as.factor(XY$genenames)
    YZ$genenames <- as.factor(YZ$genenames)

    cdXY <- chdirAnalysis(XY,
      condition,
      CalculateSig = FALSE,
      nnull = 10
    )

    cdYZ <- chdirAnalysis(YZ,
      condition,
      CalculateSig = FALSE,
      nnull = 10
    )

    angle <- getAngle(
      as.vector(cdXY$chdirprops$chdir[[1]]),
      as.vector(cdYZ$chdirprops$chdir[[1]])
    )
  }

  return(angle)
}

### NRMSD
getNRMSE <- function(gs, imp, pseudobulk = FALSE) {
  if (pseudobulk) {
    gs <- rowSums(gs)
    imp <- rowSums(imp)
    rmse <- sqrt(mean((gs - imp)**2))
  } else {
    gs <- as.matrix(gs)
    imp <- as.matrix(imp)
    rmse <- sapply(1:nrow(gs), function(i) {
      sqrt(mean((gs[i, ] - imp[i, ])**2))
    })
  }

  # normalize by range
  nrmse <- rmse / (max(gs) - min(gs))

  return(mean(nrmse))
}