#!/usr/bin/env cwl-runner
#
# validate submission file
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
    type: File?
  - id: entity_type
    type: string
  - id: question
    type: string
  - id: public_phase
    type: string

arguments:
  - position: 0
    valueFrom: |
      ${
        if (inputs.question == "1") {
          return "/validate_scrna.R"
        } else {
          return "/validate_scatac.R";
        }
      }
  - valueFrom: $(inputs.goldstandard_file.path)
    prefix: -g
  - valueFrom: $(inputs.submission_file.path)
    prefix: -s
  - valueFrom: $(inputs.entity_type)
    prefix: -e
  - valueFrom: $(inputs.public_phase)
    prefix: --public_phase
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json   

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_status'])

  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_errors'])