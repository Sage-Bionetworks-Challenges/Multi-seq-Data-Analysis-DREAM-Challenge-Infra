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
  - id: submission_file
    type: File?
  - id: entity_type
    type: string
  - id: input_dir
    type: string?
  - id: condition
    type: string[]?
  - id: proportion
    type: string[]?
  - id: file_prefix
    type: string?

arguments:
  - valueFrom: $(inputs.submission_file)
    prefix: -s
  - valueFrom: $(inputs.entity_type)
    prefix: -e
  - valueFrom: $(inputs.input_dir)
    prefix: -i
  - valueFrom: $(inputs.condition)
    prefix: -c
  - valueFrom: $(inputs.proportion)
    prefix: -p
  - valueFrom: $(inputs.file_prefix)
    prefix: -x
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