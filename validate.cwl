#!/usr/bin/env cwl-runner
#
# validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: Rscript

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720921/scoring:v1

inputs:
  - id: submission_file
    type: File?
  - id: entity_type
    type: string
  - id: input_file
    type: File
  - id: question
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
  - valueFrom: $(inputs.input_file.path)
    prefix: -i
  - valueFrom: $(inputs.submission_file.path)
    prefix: -s
  - valueFrom: $(inputs.entity_type)
    prefix: -e
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