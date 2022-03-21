### Prepare scores output
printScore <- function(scores) {
  score <- paste0("[", paste0(scores, collapse = ", "), "]")
  return(score)
}


### Characteristic Direction
getAngle <- function(a = NULL, b = NULL) {
  theta <- acos(
    sum(a * b) / (sqrt(sum(a * a)) * sqrt(sum(b * b)))
  )
  return(theta)
}

getChdir <- function(gs = NULL, down = NULL, imp = NULL) {
  XY <- cbind(genenames = rownames(gs), gs, down)
  XZ <- cbind(genenames = rownames(gs), gs, imp)
  YZ <- cbind(genenames = rownames(down), down, imp)

  XY$genenames <- as.factor(XY$genenames)
  XZ$genenames <- as.factor(XZ$genenames)
  YZ$genenames <- as.factor(YZ$genenames)

  condition <- as.factor(rep(c(1, 2), each = ncol(gs)))

  data(example_gammas)

  cdXY <- chdirAnalysis(XY,
    condition,
    gammas = example_gammas,
    CalculateSig = FALSE,
    nnull = 10
  )

  cdXZ <- chdirAnalysis(XZ,
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

  angel1 <- getAngle(
    as.vector(cdXY$chdirprops$chdir[[1]]),
    as.vector(cdXZ$chdirprops$chdir[[1]])
  )
  angel2 <- getAngle(
    as.vector(cdXY$chdirprops$chdir[[1]]),
    as.vector(cdYZ$chdirprops$chdir[[1]])
  )
  angel3 <- getAngle(
    as.vector(cdXZ$chdirprops$chdir[[1]]),
    as.vector(cdYZ$chdirprops$chdir[[1]])
  )
  avg_angel <- mean(angel1, angel2, angel3)
  return(avg_angel)
}


### NRMSD
getNRMSE <- function(gs, imp) {
  gs <- as.matrix(gs)
  imp <- as.matrix(imp)
  nrmse <- sapply(1:nrow(gs), function(i) {
    rmse <- sqrt(mean((gs[i, ] - imp[i, ])**2))
    # normalize by range
    nmse <- rmse / (max(gs[i, ]) - min(gs[i, ]))
  })
  avg_nrmse <- mean(nrmse)
  return(avg_nrmse)
}

