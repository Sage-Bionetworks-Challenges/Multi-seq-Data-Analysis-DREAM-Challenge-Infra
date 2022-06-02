#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [Rscript, /score.R]

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720921/scoring:v1

inputs:
  - id: goldstandard
    type: File
  - id: config_json
    type: File
  - id: submission_files
    type: File[]
  - id: check_validation_finished
    type: boolean?
    
arguments:
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g
  - valueFrom: $(inputs.config_json.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -o

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.config_json)
      - $(inputs.submission_files)
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
  - id: all_scores
    type: File
    outputBinding:
      glob: all_scores.csv