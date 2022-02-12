#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

hints:
  DockerRequirement:
    dockerPull: amancevice/pandas:1.4.0-slim

inputs:
  - id: input_file
    type: File?
  - id: entity_type
    type: string

arguments:
  - valueFrom: validate.py
  - valueFrom: $(inputs.input_file)
    prefix: -s
  - valueFrom: $(inputs.entity_type)
    prefix: -e
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json
          import pandas as pd
          from zipfile import ZipFile

          parser = argparse.ArgumentParser()
          parser.add_argument("-r", "--results", required=True, help="validation results")
          parser.add_argument("-e", "--entity_type", required=True, help="synapse entity type downloaded")
          parser.add_argument("-s", "--submission_file", help="Submission File")

          args = parser.parse_args()

          invalid_reasons = []
          prediction_file_status = "VALIDATED"

          if args.submission_file is None:
              prediction_file_status = "INVALID"
              invalid_reasons = ['Expected FileEntity type but found ' + args.entity_type]
          else:
              zip_file = ZipFile(args.submission_file, "r")
              ds_props = ("0_125", "0_5")
              exp_ids = ("LH2400", "LH2401", "LH7200", "LH7201")
              all_files = ["pac_real_ds_" + p + "_" + id + ".csv" for p in ds_props for id in exp_ids]
              pred_files = zip_file.namelist()
              diff = list(set(all_files) - set(pred_files))
              # check if all required data exists
              if diff:
                  invalid_reasons.append("File not found : " + "', '".join(diff))
                  prediction_file_status = "INVALID"
              else:
                  for f in pred_files:
                    df = pd.read_csv(zip_file.open(f), index_col=0)
                    # check if all value is not less than 0
                    if (df < 0).any().any():
                        invalid_reasons.append(f + ": Negative value is not allowed")
                        prediction_file_status = "INVALID"
          result = {'submission_errors': "\n".join(invalid_reasons),
                    'submission_status': prediction_file_status}
          with open(args.results, 'w') as o:
              o.write(json.dumps(result))

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