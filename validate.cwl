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
          parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

          args = parser.parse_args()
  
          invalid_reasons = []
          gs_file_status = True
          prediction_file_status = True
          exp_ids = ("2400", "2401", "7200", "7201")
          ds_props = ("0_125", "0_5")

          ## validate goldstandard file
          if args.goldstandard is None:
              gs_file_status = False
              invalid_reasons = [args.goldstandard + ' not found']
          else:
              gs_zip_file = ZipFile(args.goldstandard, "r")
              true_gs_files = ["pac_" + id  + "_gs.csv" for id in exp_ids]
              gs_diff = list(set(true_gs_files) - set(gs_zip_file.namelist()))
              # check if all required data exists
              if gs_diff:
                  invalid_reasons.append("File not found : " + "', '".join(gs_diff))
                  gs_file_status = False
              else:
                  gs_dims = [pd.read_csv(zip_file.open(gs_f), index_col=0).shape for gs_f in true_gs_files]
          ## validate prediction file
          if args.submission_file is None:
              prediction_file_status = False
              invalid_reasons = ['Expected FileEntity type but found ' + args.entity_type]
          else:
              pred_zip_file = ZipFile(args.submission_file, "r")
              # exp names, e.g. pac_2400_ds_0_125, pac_2401_ds_0_125, pac_7200_ds_0_125, 
              # pac_7201_ds_0_5, pac_2400_ds_0_5, ...
              true_pred_files = ["pac_" + id  + "_ds_" + p + ".csv" for p in ds_props for id in exp_ids]
              pred_diff = list(set(true_pred_files) - set(pred_zip_file.namelist()))
              # check if all required data exists
              if pred_diff:
                  invalid_reasons.append("File not found : " + "', '".join(pred_diff))
                  prediction_file_status = False
              else:
                  true_dims = gs_dims * len(ds_props)
                  for index, pred_f in enumerate(pred_files):
                      pred_df = pd.read_csv(zip_file.open(pred_f), index_col=0)
                      # check if all value is not less than 0
                      if (pred_df < 0).any().any():
                          invalid_reasons.append(pred_f + ": Negative value is not allowed")
                          prediction_file_status = False
                      # check if num of row/col match with what in goldstandard for each experiment
                      elif pred_df.shape == true_dims[index]:
                          invalid_reasons.append(pred_f + ": Number of genes or cells not match")
                          prediction_file_status = False
          validate_status = "VALIDATED" if gs_file_status & prediction_file_status else "INVALID"
          result = {'submission_errors': "\n".join(invalid_reasons),
                    'submission_status': validate_status}
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