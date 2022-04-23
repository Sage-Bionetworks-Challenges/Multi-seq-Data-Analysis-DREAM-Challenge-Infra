
### Characteristic Direction
getAngle <- function(a = NULL, b = NULL) {
  theta <- acos(
    sum(a * b) / (sqrt(sum(a * a)) * sqrt(sum(b * b)))
  )
  return(theta)
}

getChdir <- function(gs = NULL, down = NULL, imp = NULL, pseudo = FALSE) {
  if (pseudo) {
    XY <- data.frame(
      genenames = rownames(gs),
      gs = rowSums(gs),
      down = rowSums(down)
    )
    YZ <- data.frame(
      genenames = rownames(down),
      down = rowSums(down),
      imp = rowSums(imp)
    )
    condition <- as.factor(rep(c(1, 2), each = 1))
  } else {
    XY <- cbind(genenames = rownames(gs), gs, down)
    YZ <- cbind(genenames = rownames(down), down, imp)
    condition <- as.factor(rep(c(1, 2), each = ncol(gs)))
  }


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

  angel <- getAngle(
    as.vector(cdXY$chdirprops$chdir[[1]]),
    as.vector(cdYZ$chdirprops$chdir[[1]])
  )

  return(angel)
}


### NRMSD
getNRMSE <- function(gs, imp, pseudo = FALSE) {
  if (any(dim(gs) != dim(imp))) stop("the dimensions are not matched")

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
    nrmse <- mean(nrmse)
  }

  return(nrmse)
}
