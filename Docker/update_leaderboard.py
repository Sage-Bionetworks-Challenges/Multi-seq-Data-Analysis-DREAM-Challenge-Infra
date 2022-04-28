"""
1. query all scored submission results
2. update a leader board with rankings of the submission
"""

#!/usr/bin/env python
import synapseclient
from synapseclient.table import Table
import argparse
from scipy.stats import rankdata


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--synapse_config",
                        required=True, help="Credentials file")
    parser.add_argument("-o", "--parent_id", required=True,
                        help="Parent Id of submitter directory")
    parser.add_argument("-s", "--submission_view_synapseid",
                        required=True, help="Synapse ID of submission view")
    parser.add_argument("-l", "--leaderboard_synapseid",
                        required=True, help="Synapse ID of leader board")
    return parser.parse_args()


def valid_scores(df, col):
    """Filter out the invalid scores."""
    # not necessary for live queue
    valid_inx = []
    valid_scores = []

    for loc, res in enumerate(df[col]):
        # remove the square brackets symbols; get individual score
        scores = res[1:-1].split(", ")
        if len(scores) == 48:  # hardcode the number for now
            valid_inx.append(loc)
            valid_scores.append([float(x) for x in scores])
    return {"loc": valid_inx, "scores": valid_scores}


def rank(l):
    """Rank the item at the same index across multiple lists."""
    # get rank a list of lists for each index
    rank_list = []
    for i in range(len(l[0])):
        ranks = rankdata([x[i] for x in l])
        rank_list.append(list(ranks))
    # average of ranks for each list
    avg_rank = [(sum(r)/len(r)) for r in zip(*rank_list)]
    return avg_rank


def main():
    """Main function."""
    args = get_args()

    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)

    # create a leaderboard based on ranks of all test cases
    # set synapse ids for table views
    sv_id = args.submission_view_synapseid
    lb_id = args.leaderboard_synapseid

    # get all current submission results
    # !! ensure the columns have been already added into the leaderboard
    sv_table = syn.tableQuery(
        f"select * from {sv_id} where \
            submission_status = 'SCORED' and \
            chdir_breakdown is not null and \
            nrmse_breakdown is not null")
    df = sv_table.asDataFrame()

    # filter out invalid results (only need for testing)
    chdir_res = valid_scores(df, "chdir_breakdown")
    nrmse_res = valid_scores(df, "nrmse_breakdown")

    if chdir_res["scores"] and nrmse_res["scores"]:
        # rank scores
        chdir_rank = rank(chdir_res["scores"])
        nrmse_rank = rank(nrmse_res["scores"])

        # add ranks to valid scores
        # assume valid sub should have both valid 1st and 2rd scores
        lb_df = df.iloc[chdir_res["loc"]]
        lb_df["chdir_rank"] = chdir_rank
        lb_df["nrmse_rank"] = nrmse_rank

        # delete all rows for leaderboard table
        lb_table = syn.tableQuery(f"select * from {lb_id}")
        syn.delete(lb_table)

        # upload new results and ranks to leaderboard table
        cols = [col for col in lb_table.asDataFrame().columns]
        table = Table(lb_id, lb_df[cols])
        table = syn.store(table)


if __name__ == "__main__":
    main()
