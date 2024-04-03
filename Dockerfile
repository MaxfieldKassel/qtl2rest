# Using Rocker's R version 4.3 image as the base
FROM rocker/r-ver:4.3

# Metadata labels
LABEL author="Matthew Vincent <mattjvincent@gmail.com>"
LABEL version="1.0.0"

# Environment variables for R packages
ENV R_FORGE_PKGS Rserve
ENV R_CRAN_PKGS Rcpp R6 uuid checkmate mime jsonlite remotes

# Installing system dependencies, R packages and surpervisor
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4-openssl-dev \
    libssl-dev \
    libjemalloc-dev \
    zlib1g-dev \
    libxml2-dev \
    libgit2-dev \
    supervisor \
    cmake && \
    install2.r -r http://www.rforge.net/ $R_FORGE_PKGS && \
    install2.r $R_CRAN_PKGS && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Optional: Preload jemalloc 
# RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
#       export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so ; \
#     elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
#       export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so ; \
#     fi

# Install specific versions of R packages
RUN R -e 'remotes::install_github("rexyai/RestRserve@v1.1.1")' \
    && R -e 'remotes::install_github("mattjvincent/memCompression")' \
    && R -e 'remotes::install_version("dbplyr", version = "2.1.1")' \
    && R -e 'remotes::install_version("pryr", version = "0.1.5")' \
    && R -e 'remotes::install_version("janitor", version = "2.1.0")' \
    && R -e 'remotes::install_version("missMDA", version = "1.18")' \
    && R -e 'remotes::install_version("RSQLite", version = "2.2.9")' \
    && R -e 'remotes::install_version("gtools", version = "3.9.2")' \
    && R -e 'remotes::install_version("qtl2", version="0.28")'

# Uncomment for cache invalidation during builds
#ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

# Installing qtl2api wrapper from GitHub
RUN R -e 'remotes::install_github("churchill-lab/qtl2api@0.3.0")'

# Setting default shell
SHELL ["/bin/bash", "-c"]

# Create a non-root user for running applications
RUN useradd -ms /bin/bash myuser

# Setting up application directory
ENV INSTALL_PATH /app/qtl2rest
RUN mkdir -p $INSTALL_PATH/data/rdata $INSTALL_PATH/data/sqlite $INSTALL_PATH/conf

# Copying source and configuration files
COPY ./src/* $INSTALL_PATH/
COPY ./conf/supervisor.conf $INSTALL_PATH/conf/supervisor.conf

# Change the ownership of the copied files and directories
RUN chown -R myuser:myuser $INSTALL_PATH

# Set the working directory
WORKDIR $INSTALL_PATH

# Switch to non-root user
USER myuser

# Command to run Supervisor
CMD ["/usr/bin/supervisord", "-n", "-c", "/app/qtl2rest/conf/supervisor.conf"]