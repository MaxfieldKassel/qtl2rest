# rest2api

A Docker image for use with [qtl2api](https://github.com/churchill-lab/qtl2api). This image provides a RESTful API for interacting with a QTL analysis platform, allowing users to retrieve data, perform statistical analysis, and conduct genetic association studies.

# Prerequisites

The Docker image needs a file and a path to be mounted in the following locations:

**/app/qtl2rest/data**
 - By default, the image expects RData and Rds files to be present in this directory, which is mounted from the host machine **/data/rdata**. The RData and Rds files contain the datasets and other necessary information for the QTL analysis platform.

**ccfoundersnps.sqlite** 
- The image also expects a SQLite database file to be present in this directory, which is mounted from the host machine **/data/ccfoundersnps.sqlite**. This database file contains information about the founder strains and their genetic markers.

# Building and Running the Docker Image (With Docker Compose)

The Docker image can be built and run using Docker Compose. The `docker-compose.yml` file in this repository contains the necessary configuration for building and running the image.

## Building and Running

The following command will build and run the Docker image using Docker Compose.
```
docker-compose up --build 
```
(use -d to run in detached mode)
```
docker-compose up --build -d
```

# Building and Running the Docker Image (Without Docker Compose)

## Building

    docker build --progress plain -t churchilllab/qtl2rest .

## Running


The following command will start the Docker image.

```
    docker run --rm \
        -p 8001:8001 \
        --name qtl2rest \
        --network qtl2rest \
        -v /data/rdata:/app/qtl2rest/rdata \
        -v /data/ccfoundersnps.sqlite:/app/qtl2rest/data/ccfounders.sqlite -v \
        churchilllab/qtl2rest
```

# API Documentation

This API facilitates interactions with a QTL analysis platform, providing endpoints for data retrieval, statistical analysis, and genetic association studies. Below is a detailed overview of the available endpoints, including input parameters and expected outputs.

### General Information

- **Base URL**: The base URL for accessing the API endpoints will depend on the deployment environment. Replace `<base_url>` with the actual base URL of the API in the examples provided.

### Endpoints
#### Environment Information
##### GET `/envinfo`
- **Description**: Retrieves information about the R environment, including loaded files and their elements.
- **Inputs**: None.
- **Outputs**: A list of files loaded into the environment, along with the elements they contain.
#### Marker Information
##### GET `/markers`
- **Description**: Fetches all markers or markers for a specific chromosome.
- **Inputs**: Optional query parameter `chrom` for filtering markers by chromosome.
- **Outputs**: A list of markers, each including its location, allele information, and association data if filtered by chromosome.

#### Dataset Details
##### GET `/datasets`
- **Description**: Provides details on the datasets loaded into the environment.
- **Inputs**: None.
- **Outputs**: Information about each dataset, including name, type, annotations, sample sizes, and other metadata.

##### GET `/datasetsstats`
- **Description**: Retrieves statistical information about the datasets loaded.
- **Inputs**: None.
- **Outputs**: Statistical summaries for each dataset, such as mean, median, variance, and standard deviation of key metrics.

#### Genetic Analysis
##### GET `/rankings`
- **Description**: Returns a ranking of gene annotations for use with SNP association.
- **Inputs**: None.
- **Outputs**: A list of gene annotations ranked based on their association strength, significance levels, and other relevant metrics.

##### GET `/idexists`
- **Description**: Checks if an `id` exists in the viewer or a specified dataset.
- **Inputs**:
  - `id`: Identifier to check.
  - `dataset` (optional): Dataset to check the `id` against.
- **Outputs**: Boolean indicating the existence of the `id`.
#### LOD Analysis
##### GET `/lodpeaks`
- **Description**: Fetches LOD peaks for a specified dataset.
- **Inputs**: 
  - `dataset`: Identifier of the dataset.
- **Outputs**: A list of LOD peaks, each including its location, score, and associated markers.

##### GET `/lodscan`
- **Description**: Performs a LOD scan on an `id` in a dataset, optionally using an interactive covariate.
- **Inputs**:
  - `dataset`: Dataset identifier.
  - `id`: Identifier for the genetic element.
  - `intcovar` (optional): Interactive covariate.
- **Outputs**: LOD scores across the genome for the specified `id`, optionally adjusted for `intcovar`.

##### GET `/lodscansamples`
- **Description**: Performs a LOD scan on an `id` for a specific chromosome, grouping samples by a covariate and returning a LOD scan for each unique covariate value.
- **Inputs**:
  - `dataset`: Dataset identifier.
  - `id`: Identifier for the genetic element.
  - `chrom`: Chromosome number.
  - `intcovar`: Interactive covariate.
- **Outputs**: LOD scores for each unique `intcovar` value, including sample identifiers and their corresponding scores.

#### Expression and Association
##### GET `/expression`
- **Description**: Retrieves expression data for an `id` in a dataset.
- **Inputs**:
  - `dataset`: Dataset identifier.
  - `id`: Identifier for the gene or genetic element.
- **Outputs**: Expression levels for the specified `id`, including sample identifiers and their corresponding expression values.

##### GET `/snpassoc`
- **Description**: Conducts SNP association mapping for specified parameters.
- **Inputs**:
  - `dataset`: Dataset identifier.
  - `id`: Identifier for the genetic element.
  - `chrom`: Chromosome number.
  - `location`: Genetic location for the association mapping.
  - `window_size`: Window size for the analysis.
- **Outputs**: Association scores for SNPs within the specified window, including p-values and effect sizes.
#### Advanced Analysis
##### GET `/mediate`
- **Description**: Performs a mediation scan for an `id` and `markerID`, optionally against a different dataset.
- **Inputs**:
  - `dataset`: Primary dataset identifier.
  - `id`: Identifier for the genetic element.
  - `marker_id`: Marker identifier for the mediation analysis.
  - `dataset_mediate` (optional): Dataset for mediation analysis.
- **Outputs**: Mediation analysis results, showing the mediation effect of `marker_id` on the relationship between `id` and traits in the dataset(s).

##### GET `/foundercoefs`
- **Description**: Retrieves Founder coefficient data for specified parameters, optionally using an interactive covariate.
- **Inputs**:
  - `dataset`: Dataset identifier.
  - `id`: Identifier for the genetic element.
  - `chrom`: Chromosome number.
  - `intcovar` (optional): Interactive covariate.
- **Outputs**: Founder coefficients for the specified `id` and `chrom`, adjusted for `intcovar` if provided.

##### GET `/correlation`
- **Description**: Performs a correlation scan for an `id` in a dataset, optionally against another dataset and/or using an interactive covariate.
- **Inputs**:
  - `dataset`: Primary dataset identifier.
  - `id`: Identifier for the genetic element.
  - `dataset_correlate` (optional): Dataset for correlation analysis.
  - `intcovar` (optional): Interactive covariate.
- **Outputs**: Correlation coefficients between `id` and other genetic elements or traits, adjusted for `intcovar` if provided.

##### GET `/correlationplot`
- **Description**: Generates data for a correlation plot between two identifiers, optionally using an interactive covariate.
- **Inputs**:
  - `dataset`: Primary dataset identifier.
  - `id`: Identifier for the primary genetic element.
  - `dataset_correlate`: Dataset for the secondary genetic element.
  - `id_correlate`: Identifier for the secondary genetic element.
  - `intcovar` (optional): Interactive covariate.
- **Outputs**: Data suitable for plotting the correlation between `id` and `id_correlate`, including correlation coefficients and significance levels, adjusted for `intcovar` if provided.




