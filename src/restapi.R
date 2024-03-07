# QTL Analysis Platform API
# This R script provides a RESTful API for interacting with a QTL (Quantitative Trait Loci) analysis platform.
# It enables users to perform data retrieval, statistical analysis, and genetic association studies.
# Utilizes libraries such as RestRserve, jsonlite, memCompression, qtl2api, magrittr, and dplyr.

library(RestRserve)
library(jsonlite)
library(memCompression)
library(qtl2api)
library(magrittr)
library(dplyr)

# Middleware for GZIP Compression
# This middleware compresses the API response using GZIP if the client supports it.
# It checks the 'Accept-Encoding' request header and sets 'Content-Encoding' to 'gzip' in the response accordingly.
middleware_gzip <- Middleware$new(
    process_request = function(request, response) {
      # Request processing logic can be added here, if needed.
    },
    process_response = function(request, response) {
      enc = request$get_header("Accept-Encoding")
      if ("gzip" %in% enc) {
        response$set_header("Content-Encoding", "gzip")
        response$set_header("Vary", "Accept-Encoding")
        raw <- charToRaw(response$body)
        response$set_body(memCompression::compress(raw, "gzip"))
        response$encode = identity
      }
    },
    id = "gzip"
)

# Utility Function: Convert to Boolean/Logical
# Converts input values to boolean. Accepts TRUE, 1, "T", "TRUE", "YES", "Y", "1" as TRUE.
# @param value Input value to convert.
# @return Boolean value indicating if input is considered TRUE.
to_boolean <- function(value) {
  if (gtools::invalid(value)) {
    return(FALSE)
  } else if (is.numeric(value)) {
    return(value == 1)
  } else if (is.character(value)) {
    return(toupper(value) %in% c("T", "TRUE", "YES", "Y", "1"))
  }
  FALSE
}

# REST API Setup and Endpoint Definitions
application = Application$new(content_type = "application/json", middleware = list(middleware_gzip))

# Define API endpoints here using application$add_get() or application$add_post()
# Example:
# application$add_get(path = "/data", FUN = my_data_retrieval_function, add_head = FALSE)

# Start the Backend Server
# Initializes and starts the RestRserve backend server on port 8001.
backend = BackendRserve$new(content_type = 'application/json')
backend$start(application, http_port = 8001, encoding = "utf8", port = 6311, daemon = "disable", pid.file = "Rserve.pid")


# Function to prettify and print JSON output
# This function takes various parameters, converts them to JSON, and prints the prettified JSON string.
#
# Parameters:
# - timestamp: The timestamp for the log entry.
# - level: The log level (e.g., INFO, ERROR).
# - logger_name: The name of the logger generating the message.
# - pid: The process ID associated with the log entry.
# - message: The log message.
pretty_JSON <- function(timestamp, level, logger_name, pid, message) {
  # Convert the input parameters into a JSON string
  x = to_json(
        list(
            timestamp = format(timestamp, "%Y-%m-%d %H:%M:%OS6"), # Format timestamp
            level = as.character(level), # Ensure level is a string
            name = as.character(logger_name), # Ensure logger_name is a string
            pid = as.integer(pid), # Convert pid to integer
            message = message # Include the message as is
        )
    )
  # Print the prettified JSON string
  cat(prettify(x), file = "", append = TRUE, sep = "\n")
}

# Custom logging function for RestRServe
# This function formats log messages in a specific pattern and outputs them to the standard output.
#
# Parameters are similar to the pretty_JSON function, with an additional varargs (...) to support extra parameters.
printer_pipe <- function(timestamp, level, logger_name, pid, message, ...) {
  # Format the timestamp with time zone information
  timestamp <- format(timestamp, "%Y-%m-%d %H:%M:%OS6", usetz = TRUE, tz = 'America/New_York')
  # Format and write the log message in a custom pattern
  msg <- sprintf("%s|%s|%s|%s|%s", timestamp, level, as.character(logger_name), as.character(pid), message)
  writeLines(msg)
  flush(stdout()) # Ensure the message is immediately flushed to the output
}

# Initialize a logger with the trace level and custom printer function
logger = Logger$new("trace", printer = printer_pipe)

# Function to log errors with request context
# This function formats and logs errors including information about the HTTP request that caused the error.
#
# Parameters:
# - error: The error object or message.
# - request: The request object from RestRserve containing details about the HTTP request.
log_error <- function(error, request) {
  # Concatenate request parameters into a string
  param_string <- paste(names(request$parameters_query), request$parameters_query, sep = "=", collapse = "&")
  # Log the error with context information
  logger$error(paste0(request$path, "|", param_string, "|", error))
}


# Retrieves information about the R environment, including loaded files and their elements.
# 
# Parameters:
# - request: The request object containing the incoming HTTP request data.
# - response: The response object used to send back the HTTP response.
#
# The function attempts to collect environment information and calculates the processing time.
# If successful, it returns this data as a JSON-encoded response. In case of an error, it returns an error message with a 400 status code.
http_get_env_info <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    envObjects <- envElements

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = envElements,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve environment elements",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Fetches marker information for a given chromosome from the QTL analysis platform.
#
# Parameters:
# - request: The request object containing the incoming HTTP request data, including the "chrom" parameter to specify the chromosome.
# - response: The response object used to send back the HTTP response.
#
# This function uses the qtl2api to retrieve markers for the specified chromosome. The response includes the markers and the processing time.
# Errors are handled gracefully, returning an error message and a 400 status code if the markers cannot be retrieved.
http_get_markers <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    chrom <- request$parameters_query[["chrom"]]

    markers <- qtl2api::get_markers(chrom)

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = markers,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve markers",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Provides details on the datasets loaded into the environment, optionally collapsing detailed data into a summary format.
#
# Parameters:
# - request: The request object containing the incoming HTTP request data. The "collapse" parameter controls the format of the dataset information.
# - response: The response object used to send back the HTTP response.
#
# The function retrieves information about datasets and their annotations, optionally collapsing details for brevity. It calculates processing time for the operation.
# In the event of an error, it returns a JSON-encoded error message and sets the response status code to 400.
http_get_datasets <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    collapse <- to_boolean(request$parameters_query[["collapse"]])

    ds_info <- get_dataset_info()
    datasets <- ds_info$datasets
    ensembl_version <- ds_info$ensembl_version

    if (collapse) {
      # by converting to data.frame and setting column names to NULL, 
      # when converted to JSON, the result will be a 2 dimensional array
      for (n in 1:length(datasets)) {
        annots <- datasets[[n]]$annotations
        annots_columns <- colnames(annots)
        annots <- as.data.frame(annots)
        colnames(annots) <- NULL

        datasets[[n]]$annotations <- list(
                    columns = annots_columns,
                    data = annots
                )

        samples <- datasets[[n]]$samples
        samples_columns <- colnames(samples)
        samples <- as.data.frame(samples)
        colnames(samples) <- NULL

        datasets[[n]]$samples <- list(
                    columns = samples_columns,
                    data = samples
                )
      }
    }

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = list(
                datasets = datasets,
                ensembl_version = ensembl_version
            ),
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve datasets",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Retrieves statistical information about the datasets loaded in the environment.
#
# Parameters:
# - request: The request object containing the incoming HTTP request data.
# - response: The response object used to send back the HTTP response.
#
# This function collects and returns statistical summaries for each dataset, including the processing time for this operation.
# Errors during data retrieval result in a JSON-encoded error message and a 400 status code in the response.
http_get_datasets_stats <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    datasets <- get_dataset_stats()

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = datasets,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve dataset stats",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}


# Retrieves LOD peaks for a specified dataset, optionally expanding the details.
#
# Parameters:
# - request: The request object containing query parameters.
#   - "dataset": The dataset identifier for which LOD peaks are requested.
#   - "expand": Boolean indicating whether detailed information should be expanded.
# - response: The response object used to return data and HTTP status.
#
# The function extracts LOD peaks data from the specified dataset. If the 'expand' parameter is false,
# it simplifies the response by converting detailed data structures into a more compact form.
# It handles errors gracefully, returning a detailed error message and a 400 status code on failure.
http_get_lod_peaks <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    expand <- to_boolean(request$parameters_query[["expand"]])

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    }

    # get the LOD peaks for each covarint
    dataset <- get_dataset_by_id(dataset_id)
    peaks <- get_lod_peaks_dataset(dataset)

    if (!expand) {
      # by converting to data.frame and setting column names to NULL, 
      # when converted to JSON, the result will be a 2 dimensional array
      for (n in names(peaks)) {
        peaks[[n]] <- as.data.frame(peaks[[n]])
        colnames(peaks[[n]]) <- NULL
      }
    }

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = peaks,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve lod peaks",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Fetches rankings for genetic markers within a specified dataset, potentially limited by chromosome and number of results.
#
# Parameters:
# - request: The request object containing query parameters.
#   - "dataset": The dataset identifier for which rankings are requested.
#   - "chrom": (Optional) Chromosome to filter the rankings.
#   - "max_value": (Optional) Maximum number of ranking results to return.
# - response: The response object for returning data and HTTP status.
#
# Retrieves rankings based on dataset and optional parameters. The response includes calculated rankings,
# affected by the specified chromosome and limited to 'max_value' entries if provided.
# Errors are handled with a detailed message and a 400 status code.
http_get_rankings <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    chrom <- request$parameters_query[["chrom"]]
    max_value <- nvl_int(request$parameters_query[["max_value"]], 1000)

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    rankings <- get_rankings(
            dataset = dataset,
            chrom = chrom,
            max_value = max_value
        )

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = rankings,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve rankings",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Determines if a given identifier exists within the specified dataset or the broader database.
#
# Parameters:
# - request: The request object containing query parameters.
#   - "id": The identifier to check for existence.
#   - "dataset": (Optional) The dataset identifier to specifically search within.
# - response: The response object for returning data and HTTP status.
#
# Checks for the existence of 'id' within an optional 'dataset'. If 'dataset' is not provided, 
# it searches within the broader scope. Returns a boolean indicating the existence.
# Error handling includes a detailed message and a 400 status code on failure.
http_id_exists <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    id <- request$parameters_query[["id"]]
    dataset_id <- request$parameters_query[["dataset"]]

    if (gtools::invalid(id)) {
      stop("id is required")
    }

    if (gtools::invalid(dataset_id)) {
      ret <- qtl2api::id_exists(id)
    } else {
      dataset <- get_dataset_by_id(dataset_id)
      ret <- qtl2api::id_exists(id, dataset)
    }

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = ret,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to determine if id exists",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Performs a LOD scan for a specific identifier within a dataset, optionally adjusting for interactive covariate and parallel processing.
#
# Parameters:
# - request: The request object containing query parameters.
#   - "dataset": Dataset identifier where the scan is performed.
#   - "id": Identifier for which the LOD scan is requested.
#   - "intcovar": (Optional) Interactive covariate to adjust the LOD scores.
#   - "cores": (Optional) Number of cores to use for parallel processing.
#   - "expand": Boolean indicating whether to expand the LOD scores details.
# - response: The response object for returning data and HTTP status.
#
# Conducts a LOD scan based on provided parameters. If 'expand' is false, simplifies the LOD scores representation.
# Errors during processing result in a 400 status code and detailed error message.
http_get_lodscan <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]
    intcovar <- request$parameters_query[["intcovar"]]
    cores <- nvl_int(request$parameters_query[["cores"]], 5)
    expand <- to_boolean(request$parameters_query[["expand"]])

    if (tolower(nvl(intcovar, "")) %in% c("", "additive")) {
      intcovar <- NULL
    }

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    lod <- get_lod_scan(
            dataset = dataset,
            id = id,
            intcovar = intcovar,
            cores = cores
        )

    # we don't need the peaks, etc
    lod <- lod$lod_scores

    if (!expand) {
      # by converting to data.frame and setting column names to NULL, 
      # when converted to JSON, the result will be a 2 dimensional array
      lod <- as.data.frame(lod)
      colnames(lod) <- NULL
    }

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = lod,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve LOD scan data",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Retrieves LOD scan results by sample for a given identifier and chromosome, considering an interactive covariate.
#
# Parameters:
# - request: The request object containing query parameters.
#   - "dataset": Dataset identifier for the LOD scan.
#   - "id": Identifier for the genetic element of interest.
#   - "intcovar": Interactive covariate for the analysis.
#   - "chrom": Chromosome number to limit the LOD scan.
#   - "cores": (Optional) Number of cores for parallel processing.
#   - "expand": Boolean indicating whether to expand the results.
# - response: The response object for data return and HTTP status.
#
# Executes a LOD scan by sample within a specified chromosome and dataset, adjusting for an interactive covariate.
# Optionally utilizes multiple cores for computation. The 'expand' parameter controls the detail level of the output.
# On error, returns a 400 status code with a detailed error message.
http_get_lodscan_samples <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]
    intcovar <- request$parameters_query[["intcovar"]]
    chrom <- request$parameters_query[["chrom"]]
    cores <- nvl_int(request$parameters_query[["cores"]], 5)
    expand <- to_boolean(request$parameters_query[["expand"]])

    if (tolower(nvl(intcovar, "")) %in% c("", "additive")) {
      intcovar <- NULL
    }

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    } else if (gtools::invalid(intcovar)) {
      stop("intcovar is required")
    } else if (gtools::invalid(chrom)) {
      stop("chrom is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    lod <- get_lod_scan_by_sample(
            dataset = dataset,
            id = id,
            chrom = chrom,
            intcovar = intcovar,
            cores = cores
        )

    if (!expand) {
      # by converting to data.frame and setting column names to NULL, 
      # when converted to JSON, the result will be a 2 dimensional array
      for (element in names(lod)) {
        lod[[element]] <- as.data.frame(lod[[element]])
        colnames(lod[[element]]) <- NULL
      }
    }

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = lod,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve LOD scan data by sample",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}


# Retrieves founder coefficients for a given identifier within a dataset, optionally considering an interactive covariate.
#
# Parameters:
# - request: Contains query parameters specifying the dataset, identifier, chromosome, and options for the analysis.
# - response: Used to return data and HTTP status.
#
# Processes:
# - Validates required parameters.
# - Performs the calculation of founder coefficients, optionally adjusted for an interactive covariate and other specified options.
# - Returns the founder coefficients in a simplified format if "expand" is set to false.
#
# Error Handling:
# - Returns detailed error information and a 400 status code if required parameters are missing or an error occurs during processing.
http_get_foundercoefficients <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]
    chrom <- request$parameters_query[["chrom"]]
    intcovar <- request$parameters_query[["intcovar"]]
    blup <- to_boolean(request$parameters_query[["blup"]])
    cores <- nvl_int(request$parameters_query[["cores"]], 5)
    expand <- to_boolean(request$parameters_query[["expand"]])
    center <- to_boolean(nvl(request$parameters_query[["center"]], "TRUE"))

    if (tolower(nvl(intcovar, "")) %in% c("", "additive")) {
      intcovar <- NULL
    }

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    } else if (gtools::invalid(chrom)) {
      stop("chrom is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    effect <- get_founder_coefficients(
            dataset = dataset,
            id = id,
            chrom = chrom,
            intcovar = intcovar,
            blup = blup,
            center = center,
            cores = cores
        )

    if (!expand) {
      # by converting to data.frame and setting column names to NULL, 
      # when converted to JSON, the result will be a 2 dimensional array
      for (element in names(effect)) {
        effect[[element]] <- as.data.frame(effect[[element]])
        colnames(effect[[element]]) <- NULL
      }
    }

    elapsed <- proc.time() - ptm

    data <- list(
            request = request$path,
            parameters = request$parameters_query,
            result = effect,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve founder coefficient data",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}


# Retrieves expression data for a specific identifier within a dataset.
#
# Parameters:
# - request: Contains query parameters specifying the dataset and identifier for which expression data is requested.
# - response: Used to return data and HTTP status.
#
# Processes:
# - Validates required parameters.
# - Fetches expression data associated with the specified identifier.
# - Returns the expression data, removing unnecessary row identifiers for JSON formatting.
#
# Error Handling:
# - Returns detailed error information and a 400 status code if required parameters are missing or an error occurs during processing.
http_get_expression <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    expression <- get_expression(
            dataset = dataset,
            id = id
        )

    # eliminate the _row column down line for JSON
    rownames(expression$data) <- NULL

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = expression,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve expression data",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Performs a mediation analysis for a specific genetic element against a marker within a dataset.
#
# Parameters:
# - request: Contains query parameters specifying the dataset, identifier, marker ID, and options for the analysis.
# - response: Used to return data and HTTP status.
#
# Processes:
# - Validates required parameters.
# - Conducts mediation analysis between the specified genetic element and marker.
# - Optionally simplifies the output format if "expand" is set to false.
#
# Error Handling:
# - Returns detailed error information and a 400 status code if required parameters are missing or an error occurs during processing.
http_get_mediation <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]
    marker_id <- request$parameters_query[["marker_id"]]
    dataset_id_mediate <- request$parameters_query[["dataset_mediate"]]
    expand <- to_boolean(request$parameters_query[["expand"]])

    #if (tolower(nvl(intcovar, "")) %in% c("", "none")) {
    #    intcovar <- NULL
    #}

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    } else if (gtools::invalid(marker_id)) {
      stop("marker_id is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    dataset_mediate <-
            get_dataset_by_id(nvl(dataset_id_mediate, dataset_id))

    mediation <- get_mediation(
            dataset = dataset,
            id = id,
            marker_id = marker_id,
            dataset_mediate = dataset_mediate
        )

    if (!expand) {
      # by converting to data.frame and setting column names to NULL, 
      # when converted to JSON, the result will be a 2 dimensional array
      mediation <- as.data.frame(mediation)
      colnames(mediation) <- NULL
    }

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = mediation,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve mediation data",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Retrieves SNP association mapping data for a specific location within a dataset.
#
# Parameters:
# - request: Contains query parameters specifying the dataset, identifier, chromosome, location, and options for the analysis.
# - response: Used to return data and HTTP status.
#
# Processes:
# - Validates required parameters.
# - Performs SNP association mapping around a specified genomic location.
# - Optionally simplifies the output format if "expand" is set to false.
#
# Error Handling:
# - Returns detailed error information and a 400 status code if required parameters are missing or an error occurs during processing.
http_get_snp_assoc_mapping <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]
    chrom <- request$parameters_query[["chrom"]]
    location <- request$parameters_query[["location"]]
    window_size <- nvl_int(request$parameters_query[['window_size']],
                               500000)
    intcovar <- request$parameters_query[["intcovar"]]
    cores <- nvl_int(request$parameters_query[["cores"]], 5)
    expand <- to_boolean(request$parameters_query[["expand"]])

    if (tolower(nvl(intcovar, "")) %in% c("", "additive")) {
      intcovar <- NULL
    }

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    } else if (gtools::invalid(chrom)) {
      stop("chrom is required")
    } else if (gtools::invalid(location)) {
      stop("location is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    snp_assoc <- get_snp_assoc_mapping(
            dataset = dataset,
            id = id,
            chrom = chrom,
            location = location,
            db_file = db_file, # GLOBAL
            window_size = window_size,
            intcovar = intcovar,
            cores = cores
        )

    if (!expand) {
      # by converting to data.frame and setting column names to NULL, 
      # when converted to JSON, the result will be a 2 dimensional array
      snp_assoc <- as.data.frame(snp_assoc)
      colnames(snp_assoc) <- NULL
    }

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = snp_assoc,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve SNP association mapping data",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Retrieves correlation data for a specific identifier within a dataset, potentially across datasets.
#
# Parameters:
# - request: Contains query parameters specifying the primary dataset, identifier, secondary dataset (if correlating across datasets), and options for the analysis.
# - response: Used to return data and HTTP status.
#
# Processes:
# - Validates required parameters.
# - Calculates correlation data for the specified identifier, optionally considering an interactive covariate and limiting the number of results returned.
#
# Error Handling:
# - Returns detailed error information and a 400 status code if required parameters are missing or an error occurs during processing.
http_get_correlation <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]
    dataset_id_correlate <- request$parameters_query[["dataset_correlate"]]
    intcovar <- request$parameters_query[["intcovar"]]
    max_items <- nvl_int(request$parameters_query[["max_items"]], 10000)

    if (tolower(nvl(intcovar, "")) %in% c("", "none")) {
      intcovar <- NULL
    }

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    dataset_correlate <-
            get_dataset_by_id(nvl(dataset_id_correlate, dataset_id))

    correlations <- get_correlation(
            dataset = dataset,
            id = id,
            dataset_correlate = dataset_correlate,
            intcovar = intcovar
        )

    data <- correlations
    data <- data[1:min(max_items, NROW(data)),]

    ret <- list(correlations = data)

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = ret,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve correlation data",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

# Retrieves data necessary for plotting correlation between two identifiers, potentially across datasets.
#
# Parameters:
# - request: Contains query parameters specifying the primary dataset, primary identifier, secondary dataset, secondary identifier, and options for the analysis.
# - response: Used to return data and HTTP status.
#
# Processes:
# - Validates required parameters.
# - Fetches data suitable for generating a plot to visualize the correlation between two specified identifiers.
#
# Error Handling:
# - Returns detailed error information and a 400 status code if required parameters are missing or an error occurs during processing.
http_get_correlation_plot_data <- function(request, response) {
  result <- tryCatch({
    ptm <- proc.time()

    dataset_id <- request$parameters_query[["dataset"]]
    id <- request$parameters_query[["id"]]
    dataset_id_correlate <- request$parameters_query[["dataset_correlate"]]
    id_correlate <- request$parameters_query[["id_correlate"]]
    intcovar <- request$parameters_query[["intcovar"]]

    if (tolower(nvl(intcovar, "")) %in% c("", "none")) {
      intcovar <- NULL
    }

    if (gtools::invalid(dataset_id)) {
      stop("dataset is required")
    } else if (gtools::invalid(id)) {
      stop("id is required")
    } else if (gtools::invalid(dataset_id_correlate)) {
      stop("dataset_correlate is required")
    } else if (gtools::invalid(id_correlate)) {
      stop("id_correlate is required")
    }

    dataset <- get_dataset_by_id(dataset_id)
    dataset_correlate <-
            get_dataset_by_id(nvl(dataset_id_correlate, dataset_id))

    correlation <- get_correlation_plot_data(
            dataset = dataset,
            id = id,
            dataset_correlate = dataset_correlate,
            id_correlate = id_correlate,
            intcovar = intcovar
        )

    elapsed <- proc.time() - ptm

    data <- list(
            path = request$path,
            parameters = request$parameters_query,
            result = correlation,
            time = elapsed["elapsed"]
        )

    logger$info(paste0(request$path, "|", elapsed["elapsed"]))
    response$body <- toJSON(data, auto_unbox = TRUE)
  },
    error = function(e) {
      data <- list(
            path = request$path,
            parameters = request$parameters_query,
            error = "Unable to retrieve correlation plot data",
            details = e$message
        )
      log_error(e, request)
      response$status_code <- 400
      response$body <- toJSON(data, auto_unbox = TRUE)
    })
}

application$add_get(
    path = "/envinfo",
    FUN = http_get_env_info,
    add_head = FALSE
)

application$add_get(
    path = "/markers",
    FUN = http_get_markers,
    add_head = FALSE
)

application$add_get(
    path = "/datasets",
    FUN = http_get_datasets,
    add_head = FALSE
)

application$add_get(
    path = "/datasetsstats",
    FUN = http_get_datasets_stats,
    add_head = FALSE
)

application$add_get(
    path = "/lodpeaks",
    FUN = http_get_lod_peaks,
    add_head = FALSE
)

application$add_get(
    path = "/rankings",
    FUN = http_get_rankings,
    add_head = FALSE
)

application$add_get(
    path = "/idexists",
    FUN = http_id_exists,
    add_head = FALSE
)

application$add_get(
    path = "/lodscan",
    FUN = http_get_lodscan,
    add_head = FALSE
)

application$add_get(
    path = "/lodscansamples",
    FUN = http_get_lodscan_samples,
    add_head = FALSE
)

application$add_get(
    path = "/foundercoefs",
    FUN = http_get_foundercoefficients,
    add_head = FALSE
)

application$add_get(
    path = "/expression",
    FUN = http_get_expression,
    add_head = FALSE
)

application$add_get(
    path = "/mediate",
    FUN = http_get_mediation,
    add_head = FALSE
)

application$add_get(
    path = "/snpassoc",
    FUN = http_get_snp_assoc_mapping,
    add_head = FALSE
)

application$add_get(
    path = "/correlation",
    FUN = http_get_correlation,
    add_head = FALSE
)

application$add_get(
    path = "/correlationplot",
    FUN = http_get_correlation_plot_data,
    add_head = FALSE
)