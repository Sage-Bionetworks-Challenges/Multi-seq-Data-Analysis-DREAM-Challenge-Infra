#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: Rscript

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/

inputs:
  - id: pred_file
    type: File
  - id: input_dir
    type: string
  - id: goldstandard
    type: File
  - id: check_validation_finished
    type: boolean?

arguments:
  - valueFrom: score.R
  - valueFrom: $(inputs.pred_file.path)
    prefix: -f
  - valueFrom: $(inputs.input_dir)
    prefix: -i  
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json