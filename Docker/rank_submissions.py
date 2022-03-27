#!/usr/bin/env python
"""Script to query the all valid submissions and
update leader board results with new rankings.
"""
import argparse
import json
import synapseclient
from synapseclient.table import Table
import numpy as np
from scipy.stats import rankdata


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--synapse_config",
                        required=True, help="credentials file")
    parser.add_argument("-r", "--results", required=True,
                        help="Resulting scores")
    parser.add_argument("-s", "--submission_view_synapseid",
                        required=True, help="Synapse ID of submission view")
    parser.add_argument("-l", "--leader_board_synapseid",
                        required=True, help="Synapse ID of leader board")
    return parser.parse_args()


def valid_scores(df, col):
    """Filter out the invalid scores."""
    # not necessary for live queue
    valid_inx = []
    valid_scores = []

    for loc, res in enumerate(df[col]):
        if len(res) > 0:
            scores = res[0][1:-1].split(", ")
            if len(scores) == 8:
                valid_inx.append(loc)
                valid_scores.append([float(x) for x in scores])
    return {"index": valid_inx, "scores": valid_scores}


def rank(l):
    """Rank the item at the same index across multiple lists."""
    # get rank a list of lists for each index
    rank_list = []
    for i in range(len(l[0])):
        ranks = rankdata([x[i] for x in l])
        rank_list.append(list(ranks))
    # average of ranks for each list
    avg_rank = [np.mean(r) for r in zip(*rank_list)]
    return avg_rank


def main():
    """Main function."""
    args = get_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)

    with open(args.results) as json_data:
        annots = json.load(json_data)
    if annots.get('submission_status') is None:
        raise Exception(
            "score.cwl must return submission_status as a json key")
    status = annots['submission_status']
    if status == "SCORED":
        # set synapse ids for table views
        sv_id = args.submission_view_synapseid
        lb_id = args.leader_board_synapseid

        # get submission results
        sv_table = syn.tableQuery(
            "select * from % s where submission_status='SCORED'" % sv_id)
        df = sv_table.asDataFrame()

        # filter out invalid results
        valid_res = valid_scores(df, 'primary_metric_breakdown')

        if valid_res['scores']:
            # rank scores
            avg_rank = rank(valid_res['scores'])

            # add ranks to valid scores
            valid_df = df.iloc[valid_res['index']]
            valid_df['avg_rank'] = avg_rank
            valid_df.drop('primary_metric_breakdown', inplace=True, axis=1)

            # delete all rows for leader board table
            lb_table = syn.tableQuery("select * from % s" % lb_id)
            syn.delete(lb_table)

            # upload new results and ranks to leader board table
            valid_df.to_csv("tmp.csv", index=False)
            table = Table(lb_id, "tmp.csv")
            table = syn.store(table)


if __name__ == "__main__":
    main()
