#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  library(argparse)
  library(parallel)
  library(data.table)
  library(dplyr)
  library(bedr)
})

parser <- argparse::ArgumentParser()
parser$add_argument("-s", "--submission_file", help = "Submission file")
parser$add_argument("-g", "--goldstandard", help = "Goldstandard file")
parser$add_argument("--submission_phase", help = "Submission phase")
parser$add_argument("-o", "--results", help = "Results path")
args <- parser$parse_args()

# load evaluation metrics
source("/metrics.R")

ncores <- 10
pred_dir <- "output"
all_scores <- tibble()

# decompress
untar(args$submission_file)

## Read all data ------------------------------------
# read ground truth data
all_gs <- readRDS(args$goldstandard)

# determine phase
phase <- args$submission_phase

# read the filenames of all input data
basenames <- all_gs$down_basenames[[phase]]
pred_files <- paste0(basenames, ".bed")

chunks <- split(pred_files, ceiling(seq_along(pred_files) / 40))

# calculate scores each test case across different configurations
for (c in chunks) {
  scores_df <- mclapply(c, function(pred_file) {
    tryCatch(
      {
        # detect file prefix used to read gs
        info <- strsplit(pred_file, "\\.")[[1]]
        prefix <- info[1]
        jaccards <- list()

        # read gs
        sub_phase <- args$submission_phase
        gs <- all_gs$gs_data[[sub_phase]][[prefix]]
        gs_ranked_filtered <- gs[["gs_ranked_filtered"]]
        gs_sort <- gs[["gs_sort"]]
        gs_sort_ubi <- gs[["gs_sort_ubi"]]
        gs_sort_tss <- gs[["gs_sort_tss"]]
        gs_sort_csp <- gs[["gs_sort_csp"]]

        # read prediction
        pred <- data.table::fread(file.path(pred_dir, pred_file), data.table = FALSE, verbose = FALSE)

        jaccard_similarity <- 0
        recall_ubiquitous <- 0
        recall_tss <- 0
        recall_cellspecific <- 0
        summed_score <- 0

        if (nrow(pred) > 0) {
          colnames(pred)[1:3] <- c("chr", "start", "end")
          pred <- pred %>% filter(grepl("chr(\\d|X|Y)", chr))
          pred_sort <- bedr.merge.region(bedr.sort.region(data.frame(pred)[, 1:3], check.zero.based = FALSE, check.chr = FALSE, check.valid = FALSE), verbose = FALSE)

          # caculate scores
          j_result <- jaccard(gs_sort, pred_sort, check.merge = TRUE, check.chr = FALSE, check.sort = FALSE, check.valid = FALSE, verbose = FALSE)
          jaccard_similarity <- as.numeric(j_result$jaccard)
          recall_ubiquitous <- category_recall(gs_sort_ubi, pred_sort)
          recall_tss <- category_recall(gs_sort_tss, pred_sort)
          recall_cellspecific <- category_recall(gs_sort_csp, pred_sort)

          summed_score <- jaccard_similarity + recall_ubiquitous + recall_tss

          # report cellspecific for ds2, but not added to summed score
          if (prefix == "ds1") summed_score <- summed_score + recall_cellspecific
        }
        # collect scores for each test case
        return(
          tibble(
            dataset = pred_file,
            jaccard_similarity = jaccard_similarity,
            recall_ubiquitous = recall_ubiquitous,
            recall_tss = recall_tss,
            recall_cellspecific = recall_cellspecific,
            summed_score = summed_score
          )
        )
      },
      error = function(e) {
        print(e$message)
      }
    )
  }, mc.cores = ncores) %>% bind_rows()

  all_scores <- rbind(all_scores, scores_df)
}

## Write out the scores -----------------------------------
# save scores table to record all the test cases
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# add annotations
result_list <- list(
  primary_metric_average = mean(all_scores$summed_score, na.rm = TRUE),
  secondary_metric_average = mean(all_scores$jaccard_similarity, na.rm = TRUE),
  submission_status = "SCORED",
  submission_phase = phase
)

export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)
