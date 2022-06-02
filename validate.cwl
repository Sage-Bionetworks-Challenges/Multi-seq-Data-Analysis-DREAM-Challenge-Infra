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
  - id: input_files
    type: File[]
  - id: config_json
    type: File

arguments:
  - valueFrom: $(inputs.submission_file)
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
      - $(inputs.input_files)
      - $(inputs.config_json)
outputs:
  # output decompressed submission files,
  # so we don't need to decompress again in scoring
  - id: submission_files
    type: File[]
    outputBinding:
      glob: ./*_imputed.csv

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
    