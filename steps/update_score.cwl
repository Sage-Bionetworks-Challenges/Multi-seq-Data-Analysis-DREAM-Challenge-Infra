#!/usr/bin/env cwl-runner
#
# 1. upload the collected scores to synapse and
# 2. add the scores entity id to annotation
# 3. query all scored submission results
# 4. update a leader board with rankings of the submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: update_score_script
    type: File
  - id: synapse_config
    type: File
  - id: results
    type: File
  - id: parent_id
    type: string
  - id: all_scores
    type: File

arguments:
  - valueFrom: $(inputs.update_score_script.path)
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.parent_id)
    prefix: -o
  - valueFrom: $(inputs.results)
    prefix: -r
  - valueFrom: $(inputs.all_scores.path)
    prefix: -f

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.update_score_script)


outputs:
  - id: new_results
    type: File
    outputBinding:
      glob: results.json