#!/usr/bin/env cwl-runner
#
# Calcuate ranks and annotate submissions with new ranks
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [python3, annotate_rank.py]

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720921/scoring:v1

inputs:
  - id: synapse_config
    type: File
  - id: submission_view_id
    type: string

arguments:
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.submission_view_id)
    prefix: -s

requirements:
  - class: InlineJavascriptRequirement

outputs:
  - id: finished
    type: boolean
    outputBinding:
      outputEval: $( true )