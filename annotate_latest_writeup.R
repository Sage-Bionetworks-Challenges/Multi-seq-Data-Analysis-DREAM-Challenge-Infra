library(reticulate)
library(dplyr)
library(data.table)

# put at the start of the line - sensitive to indents
# utils <- py_run_string(
# '
# def reset_column(syn, table_id, col_name, col_type="STRING"):
#     schema = syn.get(table_id)
#     [schema.removeColumn(col) for col in syn.getColumns(schema) if col.name == col_name]
#     new_column = syn.createColumn(name=col_name, columnType=col_type)
#     schema.addColumn(new_column)
#     syn.store(schema)
#     '
# )

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
  annot_ids <-
    sub_df %>%
    group_by(submitterid) %>%
    slice_max(createdOn,n = 1) %>% 
    pull(id)
  
  # removing the column only remove it from schema,
  # but doesn't reset the values of the column
  # so have to re-annotate all rows for now
  sub_df$isLatest <- ifelse(sub_df$id %in% annot_ids, TRUE, FALSE)
  
  tryCatch(
    {
      for (j in 1:nrow(sub_df)) { # use for loop to prevent from request error
        challengeutils$annotations$annotate_submission(
          syn, 
          sub_df$id[j], 
          list(isLatest = as.logical(sub_df$isLatest[j]))
        )
      }
      message("Annotating writeup submissions with 'isLatest' DONE \u2705")
    },
    error = function(e) {
      message("Annotating writeup submissions with 'isLatest' FAIL \u274C")
      stop(e$message)
    }
  )
}