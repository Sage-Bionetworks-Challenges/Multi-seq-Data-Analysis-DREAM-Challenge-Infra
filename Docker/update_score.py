"""
1. upload the collected scores to synapse and
2. add the scores entity id to annotation
"""

#!/usr/bin/env python
import synapseclient
import argparse
import json


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


if __name__ == "__main__":
    main()
