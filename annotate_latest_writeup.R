library(reticulate)
library(dplyr)
library(data.table)

# set up env
challengeutils <- import("challengeutils")
syn <- import("synapseclient")$Synapse()
syn$login(silent = TRUE)

# assume there's only one writeup submission queue
writeup_id <- "syn46604990"

# query the writeup submission view
message("Querying writeup table ", writeup_id, " ...")
query <- sprintf("SELECT * FROM %s WHERE status = 'ACCEPTED'", writeup_id)
  
sub_df <- syn$tableQuery(query)$asDataFrame() %>%
  select(id, submitterid, createdOn)
  
if (nrow(sub_df) == 0) {
    message("No valid submission found \u274C")
  } else {
  # get latest submission by submitter
  writeup_df <-
    sub_df %>%
    group_by(submitterid) %>%
    slice_max(createdOn,n = 1)
  
  tryCatch(
    {
      for (j in 1:nrow(writeup_df)) { # use for loop to prevent from request error
        # annotate each submission with its ranks
        annots <- list(
          isLatest = as.character("yes")
        )
        challengeutils$annotations$annotate_submission(syn, writeup_df$id[j], annots)
      }
      message("Annotating writeup submissions with 'isLatest' DONE \u2705")
    },
    error = function(e) {
      message("Annotating writeup submissions with 'isLatest' FAIL \u274C")
      stop(e$message)
    }
  )
}