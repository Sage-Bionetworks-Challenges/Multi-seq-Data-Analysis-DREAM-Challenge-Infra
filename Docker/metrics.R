
### Characteristic Direction
getAngle <- function(a = NULL, b = NULL) {
  theta <- acos(
    sum(a * b) / (sqrt(sum(a * a)) * sqrt(sum(b * b)))
  )
  return(theta)
}

getChdir <- function(gs = NULL, down = NULL, imp = NULL, pseudo = FALSE) {
  if (pseudo) {
    v0 <- rowSums(gs)
    v1 <- rowSums(down)
    v2 <- rowSums(imp)
    XY <- data.frame(genenames = "", v0 = v0, v1 = v1)
    YZ <- data.frame(genenames = "", v1 = v1, v2 = v2)
    condition <- as.factor(rep(c(1, 2), each = length(gs)))
  } else {
    XY <- cbind(genenames = rownames(gs), gs, down)
    YZ <- cbind(genenames = rownames(down), down, imp)
    condition <- as.factor(rep(c(1, 2), each = ncol(gs)))

    XY$genenames <- as.factor(XY$genenames)
    YZ$genenames <- as.factor(YZ$genenames)
  }

  data(example_gammas)

  cdXY <- chdirAnalysis(XY,
    condition,
    gammas = example_gammas,
    CalculateSig = FALSE,
    nnull = 10
  )

  cdYZ <- chdirAnalysis(YZ,
    condition,
    gammas = example_gammas,
    CalculateSig = FALSE,
    nnull = 10
  )

  angel <- getAngle(
    as.vector(cdXY$chdirprops$chdir[[1]]),
    as.vector(cdYZ$chdirprops$chdir[[1]])
  )

  return(angel)
}


### NRMSD
getNRMSE <- function(gs, imp, pseudo = FALSE) {
  if (!any(dim(gs) != dim(imp))) stop("the dimensions are not matched")

  if (pseudo) {
    v0 <- rowSums(gs)
    v1 <- rowSums(imp)
    rmse <- sqrt(mean((v0 - v1)**2))
    nrmse <- rmse / (max(v0) - min(v0))
  } else {
    gs <- as.matrix(gs)
    imp <- as.matrix(imp)
    nrmse <- sapply(1:nrow(gs), function(i) {
      rmse <- sqrt(mean((gs[i, ] - imp[i, ])**2))
      # normalize by range
      rmse / (max(gs[i, ]) - min(gs[i, ]))
    })
  }

  avg_nrmse <- mean(nrmse)
  return(avg_nrmse)
}