#!/usr/bin/env python
"""Validation script for scRNA-seq signal correction.
Predictions file must be a zipped tarball archive of imputed count files:
(*.tar.gz).
Each imputed count file must have a correct file format:
(pac_expId_ds_prop_imputed.csv).
"""

import argparse
import json
import pandas as pd
from zipfile import ZipFile


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-r", "--results", required=True,
                        help="validation results")
    parser.add_argument("-e", "--entity_type", required=True,
                        help="synapse entity type downloaded")
    parser.add_argument("-s", "--submission_file", help="Submission File")
    parser.add_argument("-g", "--goldstandard", required=True,
                        help="Goldstandard for scoring")
    return parser.parse_args()


def get_dim_names(df):
    """
    Get all row names and column names of df
    """
    out = {"rownames": df.index.tolist(),
           "colnames": df.columns.values.tolist()}
    return out


def main():
    """Main function."""
    args = get_args()

    invalid_reasons = []
    gs_file_status = True
    prediction_file_status = True
    exp_ids = ["2400", "2401", "7200", "7201"]
    ds_props = ["0_125"]

    # validate goldstandard file
    if args.goldstandard is None:
        gs_file_status = False
        invalid_reasons = [args.goldstandard + ' not found']
    else:
        gs_zip_file = ZipFile(args.goldstandard, "r")
        true_gs_files = ["pac_" + id + "_gs.csv" for id in exp_ids]
        gs_diff = list(set(true_gs_files) - set(gs_zip_file.namelist()))
        # check if all required data exists
        if gs_diff:
            invalid_reasons.append("File not found : " + "', '".join(gs_diff))
            gs_file_status = False
        else:
            gs_names = [get_dim_names(gs_f) for gs_f in true_gs_files]

    # validate prediction file
    if args.submission_file is None:
        prediction_file_status = False
        invalid_reasons = [
            'Expected FileEntity type but found ' + args.entity_type]
    else:
        pred_zip_file = ZipFile(args.submission_file, "r")
        # exp names: pac_{expId}_ds_{prop}_imputed, e.g. pac_1111_ds_0_1
        true_pred_files = ["pac_" + id + "_ds_" + p +
                           "_impute.csv" for p in ds_props for id in exp_ids]
        pred_diff = list(set(true_pred_files) - set(pred_zip_file.namelist()))
        # check if all required data exists
        if pred_diff:
            invalid_reasons.append(
                "File not found : " + "', '".join(pred_diff))
            prediction_file_status = False
        else:
            true_names = gs_names * len(ds_props)
            for index, pred_f in enumerate(true_pred_files):
                pred_df = pd.read_csv(pred_zip_file.open(pred_f), index_col=0)
                pred_names = get_dim_names(pred_df)
                true_names = gs_names[index]
                cp1 = set(pred_names["rownames"]).issubset(
                    true_names["rownames"])
                cp2 = set(pred_names["colnames"]).issubset(
                    true_names["colnames"])
                # check if names of row/col match with what in goldstandard for each exp
                if not (cp1 and cp2):
                    invalid_reasons.append(
                        pred_f + ": do not contain all genes or cells")
                    prediction_file_status = False
                # check if all value is not less than 0
                elif (pred_df < 0).any().any():
                    invalid_reasons.append(
                        pred_f + ": Negative value is not allowed")
                    prediction_file_status = False

    validate_status = "VALIDATED" if gs_file_status & prediction_file_status else "INVALID"
    result = {'submission_errors': "\n".join(invalid_reasons),
              'submission_status': validate_status}
    with open(args.results, 'w') as o:
        o.write(json.dumps(result))


if __name__ == "__main__":
    main()
