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
  - id: pred_file
    type: File[]?
  - id: input_dir
    type: string
  - id: goldstandard
    type: File[]?
  - id: check_validation_finished
    type: boolean?

arguments:
  - valueFrom: $(inputs.pred_file)
    prefix: -f
  - valueFrom: $(inputs.input_dir)
    prefix: -i  
  - valueFrom: $(inputs.goldstandard)
    prefix: -g
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing: 
      - $(inputs.pred_file)
      - $(inputs.goldstandard)
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json