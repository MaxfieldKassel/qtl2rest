FROM rocker/r-ver:4.3
LABEL author="Matthew Vincent <matt.vincent@jax.org>"
LABEL version="0.5.0"


ARG TARGETPLATFORM

ENV R_CRAN_PKGS Rcpp remotes R6 uuid checkmate mime jsonlite digest
ENV R_FORGE_PKGS Rserve

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libcurl4-openssl-dev \
        libssl-dev \
        libjemalloc-dev \
        zlib1g-dev \
	supervisor && \
    install2.r -r http://www.rforge.net/ $R_FORGE_PKGS && \
    install2.r $R_CRAN_PKGS && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# https://github.com/jemalloc/jemalloc

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so ; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
      export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so ; \
    fi


# install the RestRserve, dependencies and qtl2
RUN R -e 'install.packages("RestRserve")' \
 && R -e 'remotes::install_github("mattjvincent/memCompression")'
 && R -e 'remotes::install_version("dbplyr", version = "2.1.1")' \
 && R -e 'remotes::install_version("pryr", version = "0.1.5")' \
 && R -e 'remotes::install_version("janitor", version = "2.1.0")' \
 && R -e 'remotes::install_version("missMDA", version = "1.18")' \
 && R -e 'remotes::install_version("RSQLite", version = "2.2.9")' \
 && R -e 'remotes::install_version("gtools", version = "3.9.2")' \
 && R -e 'remotes::install_version("qtl2", version="0.28")'

# Uncomment the following when wanting to force re-compile of anything below
# ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

# install the wrapper
RUN R -e 'remotes::install_github("churchill-lab/qtl2api@0.3.0")'

SHELL ["/bin/bash", "-c"]

ENV INSTALL_PATH /app/qtl2rest
RUN mkdir -p $INSTALL_PATH/data/rdata $INSTALL_PATH/data/sqlite $INSTALL_PATH/conf

WORKDIR $INSTALL_PATH

COPY ./src/* . 
COPY ./conf/supervisor.conf $INSTALL_PATH/conf/supervisor.conf

CMD ["/usr/bin/supervisord", "-n", "-c", "/app/qtl2rest/conf/supervisor.conf"]
