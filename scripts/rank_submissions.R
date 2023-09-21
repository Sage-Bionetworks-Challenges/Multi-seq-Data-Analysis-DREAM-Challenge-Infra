# this script is used to uppdate the running leaderboard rankings
library(reticulate)
library(dplyr)
library(data.table)

# set up env
challengeutils <- import("challengeutils")
syn <- import("synapseclient")$Synapse()
syn$login(silent = TRUE)

# Update all listed submission views
submission_views <- list(
  task1 = c(view = "syn51157023", eval_id = "9615023", gs = "syn34612394"),
  task2 = c(view = "syn51157023", eval_id = "9615024", gs = "syn35294386")
)

for (task_n in seq_along(submission_views)) {
  task_name <- names(submission_views)[task_n]
  task_sub_id <- submission_views[[task_n]]["view"]
  task_eval_id <- submission_views[[task_n]]["eval_id"]
  task_gs_id <- submission_views[[task_n]]["gs"]

  phase <- Sys.getenv("SUBMISSION_PHASE")
  stopifnot(phase %in% c("public", "private"))

  # retrieve the basenames from gs to filter submission view
  gs_path <- syn$get(task_gs_id)["path"]
  gs <- readRDS(gs_path)
  basenames <- gs$down_basenames[[phase]]
  if (task_n == 1) {
    pred_filenames <- paste0(basenames, "_imputed.csv")
  } else {
    pred_filenames <- paste0(basenames, ".bed")
  }

  # query the submission view
  message("Querying table - ", task_name, " in the ", phase, " phase ...")
  query <- sprintf("SELECT * FROM %s WHERE submission_status = 'SCORED' AND status = 'ACCEPTED'", task_sub_id)


  sub_df <- syn$tableQuery(query)$asDataFrame() %>%
    filter(!is.na(submission_scores), evaluationid == task_eval_id, submission_phase == phase) %>%
    select(id, submitterid, submission_scores, submission_phase) %>%
    mutate(across(everything(), as.character))

  if (nrow(sub_df) > 0) { # validate if any valid submission to prevent from failing
    # read all valid scores results
    message("Getting scores for each valid submission ...")
    if (task_n == 1) {
      primary_score <- "nrmse_score"
      secondary_score <- "spearman_score"
    } else {
      primary_score <- "summed_score"
      secondary_score <- "jaccard_similarity"
    }
    valid_colnames <- c("dataset", primary_score, secondary_score)
    all_scores <- lapply(1:nrow(sub_df), function(i) {
      syn_id <- sub_df$submission_scores[i]
      score_path <- syn$get(syn_id)$path
      score_df <- fread(score_path)
      if (any(!valid_colnames %in% colnames(score_df))) {
        return(data.frame())
      }
      if (length(setdiff(score_df$dataset, pred_filenames)) > 0) {
        return(data.frame())
      }
      score_df$id <- sub_df$id[i]
      score_df$submitterid <- sub_df$submitterid[i]
      return(score_df)
    }) %>% bind_rows()

    # rename columns
    colnames(all_scores)[which(colnames(all_scores) == primary_score)] <- "primary_score"
    colnames(all_scores)[which(colnames(all_scores) == secondary_score)] <- "secondary_score"

    if (nrow(all_scores) == 0) {
      message("No valid submission found \u274C")
    } else {
      message("Ranking scores ...")

      # correct direction of nrmse scores
      if (task_n == 1) all_scores$primary_score <- -all_scores$primary_score
      # rank the scores
      rank_df <-
        all_scores %>%
        group_by(dataset) %>%
        # rank each testcase score of one submission compared to all submissions
        # the smaller values, the smaller ranks, aka higher ranks
        mutate(
          testcase_primary_rank = rank(-primary_score),
          testcase_secondary_rank = rank(-secondary_score)
        ) %>%
        group_by(id, submitterid) %>%
        # get average scores of all testcases ranks in one submission
        summarise(
          avg_primary_rank = mean(testcase_primary_rank),
          avg_secondary_rank = mean(testcase_secondary_rank),
          .groups = "drop"
        ) %>%
        # rank overall rank on primary, tie breaks by secondary
        arrange(avg_primary_rank, avg_secondary_rank) %>%
        mutate(overall_rank = row_number())

      if (phase == "private") {
        # if private phase, re-rank the overall_rank by only ranking the BEST submission
        # non-best submissions will not be assigned overall_rank
        rank_df <-
          rank_df %>%
          group_by(submitterid) %>%
          slice_min(overall_rank, n = 1) %>%
          arrange(overall_rank) %>%
          ungroup() %>%
          mutate(overall_rank = row_number())
      }
      tryCatch(
        {
          for (j in 1:nrow(rank_df)) { # use for loop to prevent from request error
            # annotate each submission with its ranks
            annots <- list(
              primary_rank = as.double(rank_df$avg_primary_rank[j]),
              secondary_rank = as.double(rank_df$avg_secondary_rank[j]),
              overall_rank = as.integer(rank_df$overall_rank[j])
            )
            challengeutils$annotations$annotate_submission(syn, rank_df$id[j], annots)
          }
          message("Annotating ", task_name, " submissions with ranks DONE \u2705")
        },
        error = function(e) {
          message("Annotating ", task_name, " submissions with ranks FAIL \u274C")
          stop(e$message)
        }
      )
    }
  }
}
