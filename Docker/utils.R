decompress <- function(archive,
                       pattern = NULL,
                       exdir = ".",
                       junkpaths = FALSE) {
  stopifnot(grepl(".*\\.(tar\\.gz|zip)$", archive))

  if (tools::file_ext(archive) == "zip") {
    members <- unzip(archive, list = TRUE)$Name

    if (!is.null(pattern)) {
      members <- members[grepl(pattern, members)]
    } else {
      members <- members[tools::file_ext(members) != "DS_Store"]
    }

    unzip(archive, files = members, exdir = exdir, junkpaths = junkpaths)
  } else {
    members <- untar(archive, list = TRUE)
    if (!is.null(pattern)) {
      members <- members[grepl(pattern, members)]
    } else {
      members <- members[tools::file_ext(members) != "DS_Store"]
    }
    if (junkpaths) extras <- "--transform='s#^.+/##x'" else extras <- NULL
    extras <- paste0("-I pigz ", extras)
    untar(archive, files = members, extras = extras, exdir = exdir, verbose = TRUE)
  }
}
# decompress(
#   args$submission_file,
#   pattern = "*.bed",
#   exdir = pred_dir,
#   junkpaths = TRUE
# )

split_scores <- function(scores, name, limit = 100) {
  chunks <- split(scores, ceiling(seq_along(scores) / limit))
  new_scores <- lapply(chunks, function(c) paste0(c, collapse = ","))
  names(new_scores) <- paste0(name, seq_along(new_scores))
  return(new_scores)
}

# split_scores <- function(scores, limit = 100) {
#   split_l <- split(scores, ceiling(seq_along(scores) / limit))
#   str_list <- sapply(split_l, function(l) paste0(l, collapse = ","))
#   str_list <- as.character(str_list)
#   return(str_list)
# }
