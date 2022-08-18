FROM satijalab/seurat:4.0.3

RUN R -e "install.packages(c('argparse'), repos = 'http://cran.us.r-project.org')"
RUN apt-get update && apt-get install -y python3 pip
RUN cp /usr/bin/python3 /usr/bin/python
RUN pip install --upgrade pip
RUN pip install pandas synapseclient scipy

# COPY utils.py /utils.py
COPY validate_scrna.R /validate_scrna.R
COPY score_scrna.R /score_scrna.R
COPY metrics.R /metrics.R
COPY update_score.py /update_score.py
COPY update_leaderboard.py /update_leaderboard.py