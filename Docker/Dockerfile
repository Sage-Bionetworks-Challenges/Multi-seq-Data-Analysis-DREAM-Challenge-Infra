FROM satijalab/seurat:latest

RUN R -e "install.packages(c('argparse', 'GeoDE'), repos = 'http://cran.us.r-project.org')"
RUN apt-get update && apt-get install -y python3 pip
RUN cp /usr/bin/python3 /usr/bin/python
RUN pip install --upgrade pip
RUN pip install pandas synapseclient numpy

COPY validate.py /validate.py
COPY score.R /score.R
COPY metrics.R /metrics.R