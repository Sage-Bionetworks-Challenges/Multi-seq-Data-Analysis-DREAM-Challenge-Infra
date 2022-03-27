#!/usr/bin/env cwl-runner
#
# Sends score emails to participants
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.4.0

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: results
    type: File
  - id: private_annotations
    type: string[]?


arguments:
  - valueFrom: email_score.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.results)
    prefix: -r
  - valueFrom: $(inputs.private_annotations)
    prefix: -p

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: score_email.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="Credentials file")
          parser.add_argument("-r", "--results", required=True, help="Resulting scores")
          parser.add_argument("-p", "--private_annotations", nargs="+", default=[], help="Annotations to not be sent via e-mail")
          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login(silent=True)
          sub = syn.getSubmission(args.submissionid)
          participantid = sub.get("teamId")
          if participantid is not None:
            name = syn.getTeam(participantid)["name"]
          else:
            participantid = sub.userId
            name = syn.getUserProfile(participantid)["userName"]
          evaluation = syn.getEvaluation(sub.evaluationId)
          with open(args.results) as json_data:
            annots = json.load(json_data)
          if annots.get("submission_status") is None:
            raise Exception("score.cwl must return submission_status as a json key")
          if annots["submission_status"] == "SCORED":
              csv_id = annots["submission_scores"]
              del annots["submission_scores"]
              del annots["chdir_breakdown"]
              del annots["nrmse_breakdown"]
              del annots["submission_status"]
              subject = "Submission to '%s' scored!" % evaluation.name
              for annot in args.private_annotations:
                del annots[annot]
              if len(annots) == 0:
                  message = "Your submission has been scored. Results will be announced at a later time."
              else:
                  message = ["Hello %s,\n\n" % name,
                             "Your submission (id: %s) has been scored and below are the metric averages:\n\n" % sub.id,
                             "\n".join([i + " : " + str(annots[i]) for i in annots]),
                             "\nTo look at each test case's score, go here: https://www.synapse.org/#!Synapse:%s" % csv_id,
                             "\n\nSincerely,\nChallenge Administrator"]
              syn.sendMessage(
                  userIds=[participantid],
                  messageSubject=subject,
                  messageBody="".join(message))
          
outputs: []