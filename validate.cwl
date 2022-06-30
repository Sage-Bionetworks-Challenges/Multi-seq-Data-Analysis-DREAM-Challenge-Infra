#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [python3, /validate.py]

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
  - id: config_json
    type: File

arguments:
  - valueFrom: $(inputs.input_file.path)
    prefix: -i
  - valueFrom: $(inputs.submission_file.path)
    prefix: -s
  - valueFrom: $(inputs.entity_type)
    prefix: -e
  - valueFrom: $(inputs.config_json.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.config_json)
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
    