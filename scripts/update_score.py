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
