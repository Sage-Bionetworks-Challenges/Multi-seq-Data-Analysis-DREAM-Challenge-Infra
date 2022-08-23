"""

"""

#!/usr/bin/env python
import argparse
from scipy.stats import rankdata
import synapseclient
from challengeutils.annotations import annotate_submission


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--synapse_config",
                        required=True, help="Credentials file")
    parser.add_argument("-s", "--submission_view_synapseid",
                        required=True, help="Synapse ID of submission view")
    parser.add_argument("-l", "--leaderboard_synapseid",
                        required=True, help="Synapse ID of leader board")
    return parser.parse_args()


def _flatten_str(str_list):
    if str_list:
        return str_list[0].strip('][').split(', ')
    else:
        return []


def rank_testcases(submissions, ascending=True):
    """Calculate average ranks of all test cases across multiple submissions."""
    sub_ranks = []
    d = 1 if ascending else -1
    # get rank of each test case among all submissions
    for inx in range(len(submissions[0])):
        ranks = rankdata([d * float(sub[inx]) for sub in submissions])
        sub_ranks.append(list(ranks))
    # get average of ranks for each submission among all test cases ranks
    avg_rank = [(sum(test_ranks)/len(test_ranks))
                for test_ranks in zip(*sub_ranks)]
    return avg_rank


def rank_submissions(sub_df, eval_metric):
    """Determine ranks of all submissions based on metrics."""
    ranks = (sub_df[eval_metric]
             .apply(tuple, axis=1)
             .rank(method='min')
             .astype(int))
    return ranks


def annotate_ranks(syn, sub_df):
    """Annotate submissions with their new rank."""
    for _, row in sub_df.iterrows():
        annots = {"nrmse_rank": float(row["nrmse_rank"]),
                  "spearman_rank": float(row["spearman_rank"]),
                  "overall_rank": int(row["overall_rank"])
                  }
        annotate_submission(syn, row['id'], annots)


def main():
    """Main function."""
    args = get_args()

    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login(silent=True)

    eval_cols = ['nrmse_breakdown', 'spearman_breakdown']
    query = (f"SELECT id, {', '.join(eval_cols)}  FROM {subview_id} "
             f"WHERE submission_status = 'SCORED' "
             f"AND status = 'ACCEPTED'")
    sub_df = syn.tableQuery(query).asDataFrame()

    for col in eval_cols:
        sub_df[col] = sub_df[col].apply(lambda x: _flatten_str(x))

    sub_df["nrmse_rank"] = rank_testcases(sub_df["nrmse_breakdown"])
    sub_df["spearman_rank"] = rank_testcases(
        sub_df["spearman_breakdown"], ascending=False)

    sub_df["overall_rank"] = rank_submissions(
        sub_df, ["nrmse_rank", "spearman_rank"])

    annotate_ranks(syn, sub_df)


if __name__ == "__main__":
    main()
