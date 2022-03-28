"""
1. upload the collected scores to synapse and
2. add the scores entity id to annotation
3. query all scored submission results
4. update a leader board with rankings of the submission
"""

#!/usr/bin/env python
import synapseclient
import argparse
import json
from synapseclient.table import Table
from scipy.stats import rankdata


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--synapse_config",
                        required=True, help="Credentials file")
    parser.add_argument("-o", "--parent_id", required=True,
                        help="Parent Id of submitter directory")
    parser.add_argument("-r", "--results", required=True,
                        help="Resulting scores")
    parser.add_argument("-f", "--all_scores", required=True,
                        help="A csv table collected all submssion scores")
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

    with open(args.results) as json_data:
        annots = json.load(json_data)
    if annots.get("submission_status") is None:
        raise Exception(
            "score.cwl must return submission_status as a json key")
    if annots["submission_status"] == "SCORED":
        # upload the scores csv to synapse
        csv = synapseclient.File(args.all_scores, parent=args.parent_id)
        csv = syn.store(csv)
        # add scores csv to annotations
        annots["submission_scores"] = csv.id
        with open("results.json", "w") as o:
            o.write(json.dumps(annots))

         # set synapse ids for table views
        sv_id = args.submission_view_synapseid
        lb_id = args.leader_board_synapseid

        # get all current submission results
        sv_table = syn.tableQuery(
            f"select * from {sv_id} where submission_status= 'SCORED'")
        df = sv_table.asDataFrame()

        # filter out invalid results
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

            # delete all rows for leader board table
            lb_table = syn.tableQuery(f"select * from {lb_id}")
            cols = [col for col in lb_table.asDataFrame().columns]
            syn.delete(lb_table)

            # upload new results and ranks to leader board table
            lb_df[cols].to_csv("tmp.csv", index=False)
            table = Table(lb_id, "tmp.csv")
            table = syn.store(table)


if __name__ == "__main__":
    main()
