# #############################################################################
#
# Load the main data file(s).
#
# This is intended to be used in a controlled Docker environment and has
# some assumptions as to where the data files reside.
#
# For SNP association mapping, there also needs to be a SQLite
# database containing SNP information.
#
# Please see: https://github.com/churchill-lab/qtl2api/
#
# Place files with ".RData" and/or ".RDS" extension in 
# /app/qtl2rest/data/rdata as well as a file with a ".sqlite" 
# extension for the SNP database.
#
# #############################################################################

# Initialization message indicating the beginning of the data files loading process.
message("Initiating loading of data files...")

# Define variables for directories
rdata_dir <- "/app/qtl2rest/data/rdata"
sqlite_dir <- "/app/qtl2rest/data/sqlite"

# Initialize list to keep track of environment elements loaded
envElements <- list()

# Load .RData files
rdata_files <- list.files(rdata_dir, pattern = "\\.RData$", ignore.case = TRUE, full.names = TRUE)
for (f in rdata_files) {
  message("Loading RDATA file:", f)
  loaded_names <- load(f, .GlobalEnv)
  envElements <- c(envElements, list(
    fileName = basename(f),
    fileSize = file.size(f),
    elements = sort(loaded_names)
  ))
}

# Load .RDS files
rds_files <- list.files(rdata_dir, pattern = "\\.Rds$", ignore.case = TRUE, full.names = TRUE)
for (f in rds_files) {
  message("Loading RDS file:", f)
  elemName <- tools::file_path_sans_ext(basename(f))
  data <- readRDS(f)

  # Dataset validation and renaming
  if (exists('annot.samples', data) && exists('covar.info', data) &&
      exists('datatype', data) && exists('data', data) &&
      substr(elemName, 1, 8) != "dataset.") {
    elemName <- paste0("dataset.", elemName)
  }

  assign(elemName, data, .GlobalEnv)

  envElements <- c(envElements, list(
    fileName = basename(f),
    fileSize = file.size(f),
    elements = elemName
  ))
}

# Error handling for file existence
if (length(rdata_files) == 0 && length(rds_files) == 0) {
  stop("No .RData or .Rds files found in", rdata_dir)
}

# Load SQLite database file
db_file <- list.files(sqlite_dir, pattern = "\\.sqlite$", ignore.case = TRUE, full.names = TRUE)
if (length(db_file) == 0) {
  stop("No .sqlite file found in", sqlite_dir)
}

if(length(db_file) > 1) {
  stop("More than one .sqlite file found in", sqlite_dir)
}

message("Using SNP db file:", db_file)

# Cleanup: Remove temporary variables to keep the environment clean
rm(f, data, rdata_files, rds_files, db_file)

