#!/usr/bin/env cwl-runner
#
# Upload the collected scores to synapse and
# add the entity id to annotation
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: script
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
  - valueFrom: $(inputs.script.path)
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
      - $(inputs.script)
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json