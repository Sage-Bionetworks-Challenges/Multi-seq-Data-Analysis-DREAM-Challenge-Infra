
### Characteristic Direction
# getAngle <- function(a = NULL, b = NULL) {
#   theta <- acos(
#     sum(a * b) / (sqrt(sum(a * a)) * sqrt(sum(b * b)))
#   )
#   return(theta)
# }

# ### lsa Cosine
# getCosine <- function(gs, down, imp) {
#   v0 <- rowSums(gs)
#   v1 <- rowSums(down)
#   v2 <- rowSums(imp)

#   co <- lsa::cosine(v0 - v1, v2 - v1)
#   co <- as.numeric(co)
#   return(co)
# }

# ### Characteristic Direction
# getChdir <- function(gs = NULL, down = NULL, imp = NULL, pseudobulk = FALSE) {
#   if (pseudobulk) {
#     res <- getCosine(gs, down, imp)
#   } else {
#     XY <- cbind(genenames = rownames(gs), gs, down)
#     YZ <- cbind(genenames = rownames(down), down, imp)
#     condition <- as.factor(rep(c(1, 2), each = ncol(gs)))

#     XY$genenames <- as.factor(XY$genenames)
#     YZ$genenames <- as.factor(YZ$genenames)

#     cdXY <- chdirAnalysis(XY,
#       condition,
#       CalculateSig = FALSE,
#       nnull = 10
#     )

#     cdYZ <- chdirAnalysis(YZ,
#       condition,
#       CalculateSig = FALSE,
#       nnull = 10
#     )

#     res <- getAngle(
#       as.vector(cdXY$chdirprops$chdir[[1]]),
#       as.vector(cdYZ$chdirprops$chdir[[1]])
#     )
#   }

#   return(res)
# }

### NRMSD
getNRMSE <- function(gs, imp, pseudobulk = FALSE) {
  if (pseudobulk) {
    gs <- rowSums(gs)
    imp <- rowSums(imp)
    rmse <- sqrt(mean((gs - imp)**2))
    # normalize by range
    nrmse <- rmse / (max(gs) - min(gs))
  } else {
    gs <- as.matrix(gs)
    imp <- as.matrix(imp)
    nrmse <- sapply(1:nrow(gs), function(i) {
      rmse <- sqrt(mean((gs[i, ] - imp[i, ])**2))
      # normalize by range
      nrmse <- rmse / (max(gs[i, ]) - min(gs[i, ]))
    })
  }

  return(mean(nrmse))
}

getSpearman <- function(gs, imp, pseudobulk = FALSE) {
  if (pseudobulk) {
    gs <- rowSums(gs)
    imp <- rowSums(imp)
    gene_cor <- cor(gs, imp, method = "spearman")
  } else {
    gene_cor <- sapply(1:nrow(gs), function(i) {
      cor(as.numeric(gs[i, ]), as.numeric(imp[i, ]), method = "spearman")
    })
  }
  return(mean(gene_cor, na.rm = TRUE))
}