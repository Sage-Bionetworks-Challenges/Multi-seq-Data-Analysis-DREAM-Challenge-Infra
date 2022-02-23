#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [python3, /validate.py]

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn26720835/scoring-test:v1

inputs:
  - id: input_file
    type: File?
  - id: entity_type
    type: string
  - id: goldstandard
    type: File?

arguments:
  - valueFrom: validate.py
  - valueFrom: $(inputs.input_file)
    prefix: -s
  - valueFrom: $(inputs.entity_type)
    prefix: -e
  - valueFrom: $(inputs.goldstandard)
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