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
    type: File?
  - id: input_files
    type: File[]?
  - id: submission_files
    type: File[]?
  - id: check_validation_finished
    type: boolean?
  - id: condition
    type: string[]?
  - id: proportion
    type: string[]?
  - id: file_prefix
    type: string?

arguments:
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g
  - valueFrom: $(inputs.condition)
    prefix: -c
  - valueFrom: $(inputs.proportion)
    prefix: -p
  - valueFrom: $(inputs.file_prefix)
    prefix: -x
  - valueFrom: results.json
    prefix: -o

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.input_files)
      - $(inputs.submission_files)
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json