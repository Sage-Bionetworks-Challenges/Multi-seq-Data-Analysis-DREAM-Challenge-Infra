FROM satijalab/seurat:4.0.3

RUN R -e "install.packages(c('argparse', 'bedr'), repos = 'http://cran.us.r-project.org')"
RUN apt-get update && apt-get install -y --no-install-recommends pigz bedtools bedops tabix
RUN apt-get update && \
    apt-get install -y libbz2-dev liblzma-dev && \
    rm -rf /var/lib/apt/lists/*

# Install the BiocManager package in R
RUN R -e "install.packages('BiocManager')"
# Install the specified Bioconductor packages
RUN R -e "BiocManager::install(c('BSgenome.Mmusculus.UCSC.mm10', 'BSgenome.Hsapiens.UCSC.hg38'))"

COPY validate_scrna.R /validate_scrna.R
COPY validate_scatac.R /validate_scatac.R
COPY score_scrna.R /score_scrna.R
COPY score_scatac.R /score_scatac.R
COPY metrics.R /metrics.R