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
  - id: create_annotations_script
    type: File
  - id: synapse_config
    type: File
  - id: results
    type: File
  - id: parent_id
    type: string
  - id: all_scores
    type: File
  - id: max_memory
    type: string
  - id: runtime
    type: string

arguments:
  - valueFrom: $(inputs.create_annotations_script.path)
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.parent_id)
    prefix: -o
  - valueFrom: $(inputs.results)
    prefix: -r
  - valueFrom: $(inputs.runtime)
    prefix: -t
  - valueFrom: $(inputs.max_memory)
    prefix: -m
  - valueFrom: $(inputs.all_scores.path)
    prefix: -f

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.create_annotations_script)

outputs:
  - id: annotations_json
    type: File
    outputBinding:
      glob: results.json