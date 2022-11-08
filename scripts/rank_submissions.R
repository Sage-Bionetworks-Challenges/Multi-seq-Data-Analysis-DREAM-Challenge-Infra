library(reticulate)
library(dplyr)
library(data.table)

# set up env
challengeutils <- import("challengeutils")
syn <- import("synapseclient")$Synapse()
syn$login(silent = TRUE)

# Update all listed submission views
submission_views <- list(
  task1 = c(view = "syn36625504", basenames = "syn36397657")
  # task2 = c(view = "syn36625445", basenames = "syn36397602")
)

for (task_n in seq_along(submission_views)) {
  task_name <- names(submission_views)[task_n]
  task_sub_id <- submission_views[[task_n]]["view"]
  task_basenames_id <- submission_views[[task_n]]["basenames"]

  # create basenames of predictions to filter submission view
  basenames_path <- syn$get(task_basenames_id)["path"]
  basenames <- read.table(basenames_path, header = FALSE)[, 1]
  pred_filenames <- paste0(basenames, "_imputed.csv")

  # query the submission view
  phase <- Sys.getenv("SUBMISSION_PHASE")
  message("Querying table - ", task_name, " in the ", phase, " phase ...")
  query <- sprintf("SELECT * FROM %s WHERE submission_status = 'SCORED' AND status = 'ACCEPTED'", task_sub_id)


  sub_df <- syn$tableQuery(query)$asDataFrame() %>%
    filter(!is.na(submission_scores), submission_phase == is_public) %>%
    select(id, submission_scores) %>%
    mutate(across(everything(), as.character))

  # read all valid scores results
  message("Getting scores for each valid submission ...")
  valid_colnames <- c("dataset", "primary_score", "secondary_score")
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
    return(score_df)
  }) %>% bind_rows()

  if (nrow(all_scores) == 0) {
    message("No valid submission found \u274C")
  } else {
    message("Ranking scores ...")
    # rank the scores
    rank_df <-
      all_scores %>%
      group_by(dataset) %>%
      # rank each testcase score of one submission compared to all submissions
      mutate(
        testcase_primary_rank = rank(primary_score),
        testcase_secondary_rank = rank(-secondary_score)
      ) %>%
      group_by(id) %>%
      # get average scores of all testcases ranks in one submission
      summarise(
        avg_primary_rank = mean(testcase_primary_rank),
        avg_secondary_rank = mean(testcase_secondary_rank)
      ) %>%
      # rank overall rank on primary, tie breaks by secondary
      arrange(avg_primary_rank, avg_secondary_rank) %>%
      mutate(overall_rank = row_number())

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
