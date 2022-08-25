"""
Calculate the ranks and annotate the submission with new ranks
"""

from challengeutils.annotations import annotate_submission
from functools import reduce
from scipy.stats import rankdata
import synapseclient


def _drop_na(list):
    """Remove nan in a list"""
    return [x for x in list if str(x) != 'nan']


def _flatten_scores(df, columns, by=","):
    """Concatenate columns"""
    return df[columns].apply(lambda x: reduce(
        lambda a, b: _drop_na(
            ((str(a) + by + str(b)).split(by))
        ), x), axis=1)

# def _flatten_str(str_list):
#     if str_list:
#         return str_list[0].strip('][').split(', ')
#     else:
#         return []


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


def query_submissions(syn, syn_id):
    """Query the submission table"""
    # get data from the submission view table
    query = (f"SELECT * FROM {syn_id} "
             f"WHERE submission_status = 'SCORED' "
             f"AND status = 'ACCEPTED'")
    sub_df = syn.tableQuery(query).asDataFrame()
    return sub_df


def add_ranks(sub_df, bks_cols):
    """Add ranks to the submission table"""
    # clean up the scores
    # flatten the scores outcome from table to list of string
    for e in bks_cols:
        e_cols = [col for col in sub_df if col.startswith(e)]
        # sc2 might not have *-bk2 columns - cannot remove na rows directly
        # sub_df = sub_df.dropna(subset=e_cols)
        sub_df[e] = _flatten_scores(sub_df, e_cols, by=",")
        # ignore and remove empty rows
        sub_df = sub_df[sub_df[e].map(lambda x: len(x)) > 0]

        # calculate ranks across test cases
        sub_df["primary_rank"] = rank_testcases(sub_df['primary_bks'])
        sub_df["secondary_rank"] = rank_testcases(
            sub_df["secondary_bks"], ascending=False)

        # rank based on the ranks of two metrics
        sub_df["overall_rank"] = rank_submissions(
            sub_df, ["primary_rank", "secondary_rank"])

    return sub_df


def annotate_submissions_with_ranks(syn, sub_df):
    """Annotate submissions with their new ranks."""
    for _, row in sub_df.iterrows():
        annots = {"primary_rank": float(row["primary_rank"]),
                  "secondary_rank": float(row["secondary_rank"]),
                  "overall_rank": int(row["overall_rank"])
                  }
        annotate_submission(syn, row['id'], annots)


def main():
    """Main function."""
    syn = synapseclient.Synapse()
    syn.login(silent=True)

    SUBMISSION_VIEWS = {
        "Task 1": "syn27059976"
    }

    for task, syn_id in SUBMISSION_VIEWS.items():
        # get submissions
        df = query_submissions(syn_id)
        # add ranks to submission table
        bks_cols = ["primary_bks", "secondary_bks"]
        ranked_df = add_ranks(syn, df, bks_cols)
        annotate_submissions_with_ranks(syn, ranked_df)
        print(f"Annotating {task} submissions DONE ✓")


if __name__ == "__main__":
    main()
