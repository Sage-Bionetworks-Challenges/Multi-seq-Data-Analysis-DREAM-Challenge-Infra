#!/usr/bin/env cwl-runner
#
# Calcuate ranks and annotate submissions with new ranks
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: annotate_ranks_script
    type: File
  - id: synapse_config
    type: File
  - id: submission_view_synapseid
    type: string

arguments:
  - valueFrom: $(inputs.annotate_ranks_script.path)
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.submission_view_synapseid)
    prefix: -s

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.annotate_ranks_script)

outputs:
  - id: finished
    type: boolean
    outputBinding:
      outputEval: $( true )