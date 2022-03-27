#!/usr/bin/env cwl-runner
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [python3, /rank_submissions.py]

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720921/scoring:v1


inputs:
  - id: synapse_config
    type: File
  - id: results
    type: File
  - id: submission_view_synapseid
    type: string
  - id: leader_board_synapseid
    type: string

arguments:
  - valueFrom: rank_submissions.py
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.results)
    prefix: -r
  - valueFrom: $(inputs.submission_view_synapseid)
    prefix: -s
  - valueFrom: $(inputs.leader_board_synapseid)
    prefix: -l

requirements:
  - class: InlineJavascriptRequirement

outputs: []