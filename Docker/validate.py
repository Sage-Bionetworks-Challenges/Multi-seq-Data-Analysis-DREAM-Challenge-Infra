#!/usr/bin/env python
"""Validation script for scRNA-seq/scATAC signal correction.
Predictions file must be a compressed archive of imputed count files.
Each imputed count file must follow the correct file format:
(e.g. dataset1_c1_0_1_imputed.csv).
"""

import argparse
import json
import pandas as pd
import utils


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument('-r', '--results', required=True,
                        help='validation results')
    parser.add_argument('-e', '--entity_type', required=True,
                        help='synapse entity type downloaded')
    parser.add_argument('-i', '--input_file', required=True,
                        help='Input file')
    parser.add_argument('-s', '--submission_file', required=True,
                        help='Submission file')
    parser.add_argument('-c', '--config_json', required=True,
                        help='Input information json file')
    return parser.parse_args()


def _validate_scRNA(ds_files, pred_files):
    """validate on scRNA-seq data"""
    invalid_reasons = []
    # validate each prediction file
    for index, pred_f in enumerate(pred_files):
        # read ds file
        ds_df = pd.read_csv(ds_files[index], index_col=0)
        # read corresponding pred file
        pred_df = pd.read_csv(pred_f, index_col=0)
        # check if all genes exist in predictions
        cp1 = set(list(pred_df.index)).issubset(list(ds_df.index))
        # check if all cells exist in predictions
        cp2 = set(list(pred_df.columns.values)).issubset(
            list(ds_df.columns.values))
        if not (cp1 and cp2):
            invalid_reasons.append(
                f'{pred_f}: Do not contain all genes or cells')
        else:
            # check if all values are numeric
            cp3 = pred_df.apply(lambda s: pd.to_numeric(
                s, errors='coerce').isnull().any())
            if cp3.any():
                invalid_reasons.append(
                    f'{pred_f}: Not all values are numeric')
            # check if all values are >= 0
            elif (pred_df < 0).any().any():
                invalid_reasons.append(
                    f'{pred_f}: Negative value is not allowed')
    return invalid_reasons


def main():
    """Main function."""
    args = get_args()

    invalid_reasons = []

    # read json file that records downsampled data info
    with open(args.config_json) as json_data:
        input_info = json.load(json_data)
        input_info = input_info['scRNAseq']

    # for info in input_info:
    for info in input_info:
        prefix = info['dataset']
        ds_props = info['props']
        conditions = info['conditions']
        replicates = [n for n in range(1, info["replicates"] + 1)]

        # decompress submission file
        ds_fs = utils.decompress_file(args.input_file)
        # check if all required downsampled data exists
        true_ds_fs = [f'{prefix}_{c}_{p}_{n}.csv'
                      for n in replicates for p in ds_props for c in conditions]
        # downsampled files should be copied to working dir
        diff = list(set(true_ds_fs) - set(ds_fs))
        if diff:
            invalid_reasons.append('File not found : ' + '", "'.join(diff))

            # validate prediction file
        if args.submission_file is None:
            invalid_reasons.append(
                'Expected FileEntity type but found ' + args.entity_type
            )
        else:
            # decompress submission file
            pred_fs = utils.decompress_file(args.submission_file)
            true_pred_fs = [f'{prefix}_{c}_{p}_{n}_imputed.csv'
                            for n in replicates for p in ds_props for c in conditions]
            # check if all required data exists
            diff = list(set(true_pred_fs) - set(pred_fs))
            if diff:
                invalid_reasons.append('File not found : ' + '", "'.join(diff))

        if not invalid_reasons:
            scRNA_res = _validate_scRNA(true_ds_fs, true_pred_fs)
            invalid_reasons.extend(scRNA_res)

    validate_status = 'INVALID' if invalid_reasons else 'VALIDATED'
    result = {'submission_errors': '\n'.join(invalid_reasons),
              'submission_status': validate_status}
    with open(args.results, 'w') as o:
        o.write(json.dumps(result))


if __name__ == "__main__":
    main()
