#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: Rscript

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720921/evaluation:v1

inputs:
  - id: goldstandard_file
    type: File
  - id: submission_file
    type: File
  - id: question
    type: string
  - id: check_validation_finished
    type: boolean?
  - id: public_phase
    type: boolean

arguments:
  - position: 0
    valueFrom: |
      ${
        if (inputs.question == "1") {
          return "/score_scrna.R"
        } else {
          return "/score_scatac.R";
        }
      }
  - valueFrom: $(inputs.submission_file.path)
    prefix: -s
  - valueFrom: $(inputs.goldstandard_file.path)
    prefix: -g
  - valueFrom: $(inputs.public_phase)
    prefix: --public_phase
  - valueFrom: results.json
    prefix: -o

requirements:
  - class: InlineJavascriptRequirement

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
  - id: all_scores
    type: File
    outputBinding:
      glob: all_scores.csv