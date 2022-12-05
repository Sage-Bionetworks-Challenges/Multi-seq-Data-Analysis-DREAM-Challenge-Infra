FROM satijalab/seurat:4.0.3

RUN R -e "install.packages(c('argparse', 'bedr'), repos = 'http://cran.us.r-project.org')"
RUN apt-get update && apt-get install -y --no-install-recommends pigz bedtools bedops tabix

COPY validate_scrna.R /validate_scrna.R
COPY validate_scatac.R /validate_scatac.R
COPY score_scrna.R /score_scrna.R
COPY score_scatac.R /score_scatac.R
COPY metrics.R /metrics.R