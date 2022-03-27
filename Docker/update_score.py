#!/usr/bin/env python
import synapseclient
import argparse
import json

parser = argparse.ArgumentParser()
parser.add_argument("-c", "--synapse_config",
                    required=True, help="Credentials file")
parser.add_argument("-o", "--parent_id", required=True,
                    help="Parent Id of submitter directory")
parser.add_argument("-r", "--results", required=True,
                    help="Resulting scores")
parser.add_argument("-f", "--all_scores", required=True,
                    help="All scores table")

args = parser.parse_args()

syn = synapseclient.Synapse(configPath=args.synapse_config)
syn.login(silent=True)

with open(args.results) as json_data:
    annots = json.load(json_data)
if annots.get("submission_status") is None:
    raise Exception(
        "score.cwl must return submission_status as a json key")
if annots["submission_status"] == "SCORED":
    # upload the all_scores to synapse
    csv = synapseclient.File(args.all_scores, parent=args.parent_id)
    csv = syn.store(csv)
    # add all_scores to annotations
    annots["submission_scores"] = csv.id
    with open("results.json", "w") as o:
        o.write(json.dumps(annots))
