#!/usr/bin/env cwl-runner
class: CommandLineTool
cwlVersion: v1.0
baseCommand: unzip

inputs:
  - id: zipped_file
    type: File?

arguments:
  - valueFrom: $(inputs.zipped_file.path)

outputs:
  unzipped_file:
    type: File[]
    outputBinding:
      glob: ./*.csv