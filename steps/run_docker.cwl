#!/usr/bin/env cwl-runner
#
# Run Docker Submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: submissionid
    type: int
  - id: docker_repository
    type: string
  - id: docker_digest
    type: string
  - id: docker_registry
    type: string
  - id: docker_authentication
    type: string
  - id: parentid
    type: string
  - id: docker_status
    type: string
  - id: synapse_config
    type: File
  - id: input_dir
    type: string
  - id: docker_script
    type: File
  - id: store
    type: boolean?
  - id: question
    type: string
  - id: submission_phase
    type: string

arguments: 
  - valueFrom: $(inputs.docker_script.path)
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.docker_repository)
    prefix: -p
  - valueFrom: $(inputs.docker_digest)
    prefix: -d
  - valueFrom: $(inputs.store)
    prefix: --store
  - valueFrom: $(inputs.docker_status)
    prefix: --docker_status
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.question)
    prefix: -q
  - valueFrom: $(inputs.input_dir)
    prefix: -i
  - valueFrom: $(inputs.submission_phase)
    prefix: --submission_phase
  
requirements:
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.docker_script)
      - entryname: .docker/config.json
        entry: |
          {"auths": {"$(inputs.docker_registry)": {"auth": "$(inputs.docker_authentication)"}}}
  - class: InlineJavascriptRequirement

outputs:
  - id: submission_file
    type: File?
    outputBinding:
      glob: predictions.tar.gz
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
  - id: runtime
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_runtime'])
  - id: max_memory
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_max_memory'])