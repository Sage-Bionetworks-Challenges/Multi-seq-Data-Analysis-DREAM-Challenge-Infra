#!/usr/bin/env Rscript

## Load ------------------------------------
suppressPackageStartupMessages({
  library(argparse)
  library(parallel)
  library(data.table)
  library(dplyr)
  library(bedr)
  library(pbmcapply)
  # library(GenomicRanges)
  library(BSgenome.Mmusculus.UCSC.mm10)
  library(BSgenome.Hsapiens.UCSC.hg38)
})

parser <- argparse::ArgumentParser()
parser$add_argument("-s", "--submission_file", help = "Submission file")
parser$add_argument("-g", "--goldstandard", help = "Goldstandard file")
parser$add_argument("--submission_phase", help = "Submission phase")
parser$add_argument("-o", "--results", help = "Results path")
args <- parser$parse_args()

# load evaluation functions
source("/metrics.R")

# read args and set variables
submission_file <- args$submission_file
goldstandard_file <- args$goldstandard
phase <- args$submission_phase
ncores <- 10
output_dir <- "output"
all_scores <- tibble()

# get submissions files
untar(args$submission_file)

## Read all data ------------------------------------
# read ground truth data
all_gs <- readRDS(goldstandard_file)
bed_files <- paste0(all_gs$down_basenames[[phase]], ".bed")

## Dataset 1 ------------------------------------
message("Loading data from '", submission_folder, "' ...")
ds1_bed_files <- bed_files[grepl("ds1", bed_files)]

ds1_merged_filename <- paste0(submission_folder, "_DATASET1_merged_peak_", phase, ".bed")
if (file.exists(file.path(output_dir, ds1_merged_filename))) {
  ds1_merged_peaks <- data.table::fread(file.path(output_dir, ds1_merged_filename), data.table = FALSE, verbose = FALSE)
} else {
  message("Pad peaks for DATASET1 - mouse mm10")
  all_ds1_peaks <- pbmclapply(ds1_bed_files, function(bed_file) {
    peak_data <- data.table::fread(file.path(submission_folder, bed_file), data.table = FALSE, verbose = FALSE)
    if (nrow(peak_data) > 0) {
      peak_data <- correct_peaks(peak_data)
      peak_data <- pad_peaks(peak_data, genome = Mmusculus, padding = 150)
    }
    return(peak_data)
  }, mc.cores = ncores)

  message("Merge peaks for DATASET1")

  ds1_merged_peaks <- all_ds1_peaks %>%
    rbindlist(fill = TRUE) %>%
    as.data.frame() %>%
    bedr.sort.region(
      check.zero.based = FALSE,
      check.chr = FALSE,
      check.valid = FALSE,
      check.merge = FALSE,
      verbose = FALSE
    ) %>%
    bedr.merge.region(
      check.sort = FALSE,
      check.valid = FALSE,
      check.chr = FALSE,
      check.zero.based = FALSE,
      verbose = FALSE
    )
  # Although GenomicRanges's merging is faster, but stick with bedr to have consistent sorting
  # ds1_gr <- GRanges(seqnames = ds1_gr$chr, ranges = IRanges(start = ds1_gr$start, end = ds1_gr$end))
  # ds1_gr_sorted <- GenomicRanges::sort(ds1_gr)
  # ds1_gr_merged <- GenomicRanges::reduce(ds1_gr_sorted)
  # ds1_merged_peaks <- as.data.frame(ds1_gr_merged)
  fwrite(ds1_merged_peaks, file.path(output_dir, paste0(submission_folder, "_DATASET1_merged_peak_", phase, ".bed")))
}

message("Scoring ...")
all_scores <-
  tryCatch(
    {
      ds1_peaks <- ds1_merged_peaks

      # define initial values
      ds1_jaccard_similarity <- 0
      ds1_recall_ubiquitous <- 0
      ds1_recall_tss <- 0
      ds1_recall_cellspecific <- 0
      ds1_summed_score <- 0

      if (nrow(ds1_peaks) > 0) {
        # read gs
        ds1_gs <- all_gs$gs_data[[phase]][["ds1"]]
        # caculate scores
        # ds1_peaks <- bedr.sort.region(data.frame(ds1_peaks)[, 1:3], check.zero.based = FALSE, check.chr = FALSE, check.valid = FALSE, check.merge = FALSE)
        ds1_j_result <- jaccard(ds1_gs[["gs_sort"]], ds1_peaks, check.merge = FALSE, check.chr = FALSE, check.sort = FALSE, check.valid = FALSE, check.zero.based = FALSE, verbose = FALSE)
        ds1_jaccard_similarity <- as.numeric(ds1_j_result$jaccard)
        ds1_recall_ubiquitous <- category_recall(ds1_gs[["gs_sort_ubi"]], ds1_peaks)
        ds1_recall_tss <- category_recall(ds1_gs[["gs_sort_tss"]], ds1_peaks)
        ds1_recall_cellspecific <- category_recall(ds1_gs[["gs_sort_csp"]], ds1_peaks)

        ds1_summed_score <- ds1_jaccard_similarity + ds1_recall_ubiquitous + ds1_recall_tss
      }

      # collect scores for both datasets
      tibble(
        ds1_recall_ubiquitous = ds1_recall_ubiquitous,
        ds1_recall_tss = ds1_recall_tss,
        ds1_recall_cellspecific = ds1_recall_cellspecific,
        ds1_jaccard_similarity = ds1_jaccard_similarity,
        ds1_summed_score = ds1_summed_score
      )
    },
    error = function(e) {
      print(e$message)
    }
  )

# Datset 2 ------------------------------------
# repeat on dataset 2 scores for private phase
if (phase == "private") {
  ds2_bed_files <- bed_files[grepl("ds2", bed_files)]
  ds2_merged_filename <- paste0(submission_folder, "_DATASET2_merged_peak_", phase, ".bed")

  if (file.exists(file.path(output_dir, ds2_merged_filename))) {
    ds2_merged_peaks <- data.table::fread(file.path(output_dir, ds2_merged_filename), data.table = FALSE, verbose = FALSE)
  } else {
    message("Pad peaks for DATASET2 - human hg38")
    all_ds2_peaks <- pbmclapply(ds2_bed_files, function(bed_file) {
      peak_data <- data.table::fread(file.path(submission_folder, bed_file), data.table = FALSE, verbose = FALSE)
      if (nrow(peak_data) > 0) {
        peak_data <- correct_peaks(peak_data)
        peak_data <- pad_peaks(peak_data, genome = Hsapiens, padding = 150)
      }
      return(peak_data)
    }, mc.cores = ncores)

    message("Merge peaks for DATASET2 ...")
    ds2_merged_peaks <- all_ds2_peaks %>%
      rbindlist(fill = TRUE) %>%
      as.data.frame() %>%
      bedr.sort.region(
        check.zero.based = FALSE,
        check.chr = FALSE,
        check.valid = FALSE,
        check.merge = FALSE,
        verbose = FALSE
      ) %>%
      bedr.merge.region(
        check.sort = FALSE,
        check.valid = FALSE,
        check.chr = FALSE,
        check.zero.based = FALSE,
        verbose = FALSE
      )
    fwrite(ds2_merged_peaks, file.path(output_dir, paste0(submission_folder, "_DATASET2_merged_peak_", phase, ".bed")))
  }

  ds2_scores <-
    tryCatch(
      {
        ds2_peaks <- ds2_merged_peaks

        # define initial values
        ds2_jaccard_similarity <- 0
        ds2_recall_ubiquitous <- 0
        ds2_recall_tss <- 0
        ds2_recall_cellspecific <- 0
        ds2_summed_score <- 0

        if (nrow(ds2_peaks) > 0) {
          # read gs
          ds2_gs <- all_gs$gs_data[[phase]][["ds2"]]
          # caculate scores
          # ds2_peaks <- bedr.sort.region(data.frame(ds2_peaks)[, 1:3], check.zero.based = FALSE, check.chr = FALSE, check.valid = FALSE, check.merge = FALSE)
          ds2_j_result <- jaccard(ds2_gs[["gs_sort"]], ds2_peaks, check.merge = FALSE, check.chr = FALSE, check.sort = FALSE, check.valid = FALSE, check.zero.based = FALSE, verbose = FALSE)
          ds2_jaccard_similarity <- as.numeric(ds2_j_result$jaccard)
          ds2_recall_ubiquitous <- category_recall(ds2_gs[["gs_sort_ubi"]], ds2_peaks)
          ds2_recall_tss <- category_recall(ds2_gs[["gs_sort_tss"]], ds2_peaks)
          ds2_recall_cellspecific <- category_recall(ds2_gs[["gs_sort_csp"]], ds2_peaks)

          # add cellspecific for ds2
          ds2_summed_score <- ds2_jaccard_similarity + ds2_recall_ubiquitous + ds2_recall_tss + ds2_recall_cellspecific
        }

        # collect scores for both datasets
        tibble(
          ds2_recall_ubiquitous = ds2_recall_ubiquitous,
          ds2_recall_tss = ds2_recall_tss,
          ds2_recall_cellspecific = ds2_recall_cellspecific,
          ds2_jaccard_similarity = ds2_jaccard_similarity,
          ds2_summed_score = ds2_summed_score
        )
      },
      error = function(e) {
        print(e$message)
      }
    )

  all_scores <- cbind(all_scores, ds2_scores)
}

## Write out the scores -----------------------------------
# save scores table to record all the test cases
write.csv(all_scores, "all_scores.csv", row.names = FALSE)

# add annotations reporting to participants
result_list <- list(
  primary_metric_average = as.numeric(mean(all_scores$ds1_summed_score, all_scores$ds2_summed_score, na.rm = TRUE)),
  secondary_metric_average = as.numeric(mean(all_scores$ds1_jaccard_similarity, all_scores$ds2_jaccard_similarity, na.rm = TRUE)),
  submission_status = "SCORED",
  submission_phase = phase
)

export_json <- jsonlite::toJSON(result_list, auto_unbox = TRUE, pretty = TRUE)
write(export_json, args$results)
