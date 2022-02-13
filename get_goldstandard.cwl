#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [ python3, get_gold.py ]

inputs: []

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: get_gold.py
        entry: |
          #!/usr/bin/env python
          import subprocess
          # Run these commands to mount files into docker containers
          # docker run -v truth:/goldstandard/ --name helper busybox true
          # docker cp /home/ec2-user/challenge-data/goldstandard/goldstandard.zip helper:/goldstandard/goldstandard.zip
          subprocess.check_call(["docker", "cp", "helper:/goldstandard/goldstandard.zip", "goldstandard.zip"])

outputs:
  - id: goldstandard
    type: File
    outputBinding:
      glob: goldstandard.zip