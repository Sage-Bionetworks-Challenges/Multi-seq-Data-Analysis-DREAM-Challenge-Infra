#!/usr/bin/env cwl-runner
#
# 1. query all scored submission results
# 2. update a leader board with rankings of the submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: update_leaderboard_script
    type: File
  - id: synapse_config
    type: File
  - id: annotate_submission_with_output
    type: boolean
  - id: submission_view_synapseid
    type: string
  - id: leaderboard_synapseid
    type: string

arguments:
  - valueFrom: $(inputs.update_leaderboard_script.path)
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.submission_view_synapseid)
    prefix: -s
  - valueFrom: $(inputs.leaderboard_synapseid)
    prefix: -l

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.update_leaderboard_script)

outputs:
  - id: finished
    type: boolean
    outputBinding:
      outputEval: $( true )