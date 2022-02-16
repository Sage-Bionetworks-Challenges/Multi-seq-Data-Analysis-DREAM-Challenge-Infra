#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [Rscript, /score.R]

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720835/scoring-test:v1

inputs:
  - id: goldstandard
    type: File[]?
  - id: input_files
    type: File[]?
  - id: predictions
    type: File[]?
  - id: check_validation_finished
    type: boolean?

arguments:
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.goldstandard)
      - $(inputs.input_files)
      - $(inputs.predictions)
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json