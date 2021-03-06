create_infotables <- function (data = NULL, valid = NULL, y = NULL, bins = 10, trt = NULL, 
                               ncore = NULL, parallel = TRUE) 
{
  combine <- function(x, ...) {
    lapply(seq_along(x), function(i) c(x[[i]], lapply(list(...), 
                                                      function(y) y[[i]])))
  }
  if (is.null(data)) {
    stop("Error: No dataset provided")
  }
  crossval <- TRUE
  if (is.null(valid)) {
    crossval <- FALSE
  }
  c <- CheckInputs(data, valid, trt, y)
  data <- c[[1]]
  if (crossval == TRUE) {
    valid <- c[[2]]
  }
  variables <- names(data)[!(names(data) %in% c(trt, y))]
  d_netlift <- 0
  if (is.null(trt) == FALSE) {
    d_netlift <- 1
  }
  i <- NULL
  if (length(variables) == 0) {
    stop("ERROR: no variables left after screening")
  }
  if (parallel == TRUE) {
    if (is.null(ncore)) {
      ncore <- detectCores() - 1
    }
    if (ncore < 1) 
      ncore <- 1
    registerDoParallel(ncore)
    loopResult <- foreach(i = 1:length(variables), .combine = "combine", 
                          .multicombine = TRUE, .init = list(list(), list())) %dopar% 
                          {
                            data$var <- data[[variables[i]]]
                            cuts <- NULL
                            if (crossval == TRUE) {
                              valid$var <- valid[[variables[i]]]
                              if (is.character(data[[variables[i]]]) != is.character(valid[[variables[i]]])) {
                                stop(paste0("ERROR: variable type mismatch for ", 
                                            variables[i], " across validation and training (not a character in both dataframes)"))
                              }
                              if (is.factor(data[[variables[i]]]) != is.factor(valid[[variables[i]]])) {
                                stop(paste0("ERROR: variable type mismatchfor ", 
                                            variables[i], " across validation and training dataframes (not a factor in both dataframes)"))
                              }
                            }
                            if (is.character(data[[variables[i]]]) == FALSE & 
                                is.factor(data[[variables[i]]]) == FALSE) {
                              q <- quantile(data[[variables[i]]], probs = c(1:(bins - 
                                                                                 1)/bins), na.rm = TRUE, type = 3)
                              cuts <- unique(q)
                            }
                            summary_train <- Aggregate(data, variables[i], 
                                                       y, cuts, trt)
                            if (crossval == TRUE) {
                              summary_valid <- Aggregate(valid, variables[i], 
                                                         y, cuts, trt)
                            }
                            if (d_netlift == 0) {
                              woe_train <- WOE(summary_train, variables[i])
                              if (crossval == TRUE) {
                                woe_valid <- WOE(summary_valid, variables[i])
                              }
                              if (crossval == TRUE) {
                                woe_train <- penalty(woe_train, woe_valid, 
                                                     0)
                              }
                              woe_train[, c("IV_weight")] <- NULL
                              strength <- data.frame(variables[i], woe_train[nrow(woe_train), 
                                                                             "IV"])
                              names(strength) <- c("Variable", "IV")
                              if (crossval == TRUE) {
                                strength$PENALTY <- woe_train[nrow(woe_train), 
                                                              "PENALTY"]
                                strength$AdjIV <- strength$IV - strength$PENALTY
                              }
                            }
                            else {
                              nwoe_train <- NWOE(summary_train, variables[i])
                              if (crossval == TRUE) {
                                nwoe_valid <- NWOE(summary_valid, variables[i])
                              }
                              if (crossval == TRUE) {
                                nwoe_train <- penalty(nwoe_train, nwoe_valid, 
                                                      1)
                              }
                              nwoe_train[, c("NIV_weight")] <- NULL
                              strength <- data.frame(variables[i], nwoe_train[nrow(nwoe_train), 
                                                                              "NIV"])
                              names(strength) <- c("Variable", "NIV")
                              if (crossval == TRUE) {
                                strength$PENALTY <- nwoe_train[nrow(nwoe_train), 
                                                               "PENALTY"]
                                strength$AdjNIV <- strength$NIV - strength$PENALTY
                              }
                            }
                            if (d_netlift == 1) {
                              nwoe_train$key <- NULL
                              list(nwoe_train, strength)
                            }
                            else {
                              woe_train$key <- NULL
                              list(woe_train, strength)
                            }
                          }
    tables <- loopResult[[1]]
    stats <- data.frame(rbindlist(loopResult[[2]]))
    stopImplicitCluster()
    rm(loopResult)
    gc()
  }
  else {
    statslist <- list(length = length(variables))
    tables <- list(length = length(variables))
    for (i in 1:length(variables)) {
      data$var <- data[[variables[i]]]
      cuts <- NULL
      if (crossval == TRUE) {
        valid$var <- valid[[variables[i]]]
        if (is.character(data[[variables[i]]]) != is.character(valid[[variables[i]]])) {
          stop(paste0("ERROR: variable type mismatch for ", 
                      variables[i], " across validation and training (not a character in both dataframes)"))
        }
        if (is.factor(data[[variables[i]]]) != is.factor(valid[[variables[i]]])) {
          stop(paste0("ERROR: variable type mismatchfor ", 
                      variables[i], " across validation and training dataframes (not a factor in both dataframes)"))
        }
      }
      if (is.character(data[[variables[i]]]) == FALSE & 
          is.factor(data[[variables[i]]]) == FALSE) {
        q <- quantile(data[[variables[i]]], probs = c(1:(bins - 
                                                           1)/bins), na.rm = TRUE, type = 3)
        cuts <- unique(q)
      }
      summary_train <- Aggregate(data, variables[i], y, 
                                 cuts, trt)
      if (crossval == TRUE) {
        summary_valid <- Aggregate(valid, variables[i], 
                                   y, cuts, trt)
      }
      if (d_netlift == 0) {
        woe_train <- WOE(summary_train, variables[i])
        if (crossval == TRUE) {
          woe_valid <- WOE(summary_valid, variables[i])
        }
        if (crossval == TRUE) {
          woe_train <- penalty(woe_train, woe_valid, 
                               0)
        }
        woe_train[, c("IV_weight")] <- NULL
        strength <- data.frame(variables[i], woe_train[nrow(woe_train), 
                                                       "IV"])
        names(strength) <- c("Variable", "IV")
        if (crossval == TRUE) {
          strength$PENALTY <- woe_train[nrow(woe_train), 
                                        "PENALTY"]
          strength$AdjIV <- strength$IV - strength$PENALTY
        }
      }
      else {
        nwoe_train <- NWOE(summary_train, variables[i])
        if (crossval == TRUE) {
          nwoe_valid <- NWOE(summary_valid, variables[i])
        }
        if (crossval == TRUE) {
          nwoe_train <- penalty(nwoe_train, nwoe_valid, 
                                1)
        }
        nwoe_train[, c("NIV_weight")] <- NULL
        strength <- data.frame(variables[i], nwoe_train[nrow(nwoe_train), 
                                                        "NIV"])
        names(strength) <- c("Variable", "NIV")
        if (crossval == TRUE) {
          strength$PENALTY <- nwoe_train[nrow(nwoe_train), 
                                         "PENALTY"]
          strength$AdjNIV <- strength$NIV - strength$PENALTY
        }
      }
      statslist[[i]] <- strength
      if (d_netlift == 1) {
        nwoe_train$key <- NULL
        tables[[i]] <- nwoe_train
      }
      else {
        woe_train$key <- NULL
        tables[[i]] <- woe_train
      }
    }
    stats <- data.frame(rbindlist(statslist))
  }
  if (crossval == TRUE) {
    if (d_netlift == 0) {
      stats <- stats[order(-stats$AdjIV), ]
    }
    else {
      stats <- stats[order(-stats$AdjNIV), ]
    }
  }
  else {
    if (d_netlift == 0) {
      stats <- stats[order(-stats$IV), ]
    }
    else {
      stats <- stats[order(-stats$NIV), ]
    }
  }
  stats$Variable <- as.character(stats$Variable)
  names(tables) <- variables
  object <- list(Tables = tables, Summary = stats)
  class(object) <- "Information"
  return(object)
}