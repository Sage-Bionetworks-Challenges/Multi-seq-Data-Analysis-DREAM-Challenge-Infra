#!/usr/bin/env cwl-runner
#
# 1. query all scored submission results
# 2. update a leader board with rankings of the submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [python3, /update_leaderboard.py]

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720921/scoring:v1

inputs:
  - id: synapse_config
    type: File
  - id: parent_id
    type: string
  - id: annotate_submission_with_output
    type: boolean
  - id: submission_view_synapseid
    type: string
  - id: leaderboard_synapseid
    type: string

arguments:
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.parent_id)
    prefix: -o
  - valueFrom: $(inputs.submission_view_synapseid)
    prefix: -s
  - valueFrom: $(inputs.leaderboard_synapseid)
    prefix: -l

requirements:
  - class: InlineJavascriptRequirement

outputs:
  - id: finished
    type: boolean
    outputBinding:
      outputEval: $( true )