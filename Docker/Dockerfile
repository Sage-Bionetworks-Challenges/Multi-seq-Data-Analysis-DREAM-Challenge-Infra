FROM satijalab/seurat:latest

RUN R -e "install.packages(c('argparse', 'GeoDE', 'lsa'), repos = 'http://cran.us.r-project.org')"
RUN apt-get update && apt-get install -y python3 pip
RUN cp /usr/bin/python3 /usr/bin/python
RUN pip install --upgrade pip
RUN pip install pandas synapseclient scipy

COPY validate.py /validate.py
COPY update_score.py /update_score.py
COPY score.R /score.R
COPY metrics.R /metrics.R