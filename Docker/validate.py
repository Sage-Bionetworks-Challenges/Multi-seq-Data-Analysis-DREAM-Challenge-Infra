#!/usr/bin/env python
"""Validation script for scRNA-seq/scATAC signal correction.
Predictions file must be a compressed archive of imputed count files.
Each imputed count file must follow the correct file format:
(e.g. dataset1_c1_0_1_imputed.csv).
"""

import argparse
import json
import pandas as pd
import os
import tarfile
import zipfile
import shutil


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument('-r', '--results', required=True,
                        help='validation results')
    parser.add_argument('-e', '--entity_type', required=True,
                        help='synapse entity type downloaded')
    parser.add_argument('-s', '--submission_file', required=True,
                        help='Submission file')
    parser.add_argument('-c', '--condition', required=True, nargs='+',
                        help='Experiment condition')
    parser.add_argument('-p', '--proportion', required=True, nargs='+',
                        help='Downsampling proportion')
    parser.add_argument('-x', '--file_prefix', required=True,
                        help='Prefix of filename')
    parser.add_argument('-q', '--question', required=True,
                        help='Challenge question')
    return parser.parse_args()


def _filter_files(members, type='tar'):
    """Filter out non-csv files in zip file."""
    if type == "tar":
        new_members = filter(
            lambda member: member.name.endswith('.csv'), members)
    else:
        new_members = filter(lambda member: member.endswith('.csv'), members)
    new_members = list(new_members)
    return new_members


def _decompress_file(f):
    """Untar or unzip file."""
    names = []
    # decompress zip file
    if zipfile.is_zipfile(f):
        with zipfile.ZipFile(f) as zip_ref:
            members = zip_ref.namelist()
            members = _filter_files(members, type='zip')
            if members:
                for member in members:
                    member_name = os.path.basename(member)
                    with zip_ref.open(member) as source, open(member_name, 'wb') as target:
                        # copy it directly to skip the folder names
                        shutil.copyfileobj(source, target)
                    names.append(member_name)
    # decompress tar file
    elif tarfile.is_tarfile(f):
        with tarfile.open(f) as tar_ref:
            members = tar_ref.getmembers()
            members = _filter_files(members)
            if members:
                for member in members:
                    # skip the folder names
                    member.name = os.path.basename(member.name)
                    tar_ref.extract(member)
                    names.append(member.name)
    return names


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

    # set variables to find files
    ds_props = args.proportion
    conditions = args.condition
    file_prefix = args.file_prefix

    # check if all required downsampled data exists
    true_ds_fs = [f'{file_prefix}_{c}_{p}.csv'
                  for p in ds_props for c in conditions]
    # downsampled files should be copied to working dir
    diff = list(set(true_ds_fs) - set(os.listdir(".")))
    if diff:
        invalid_reasons.append('File not found : ' + '", "'.join(diff))

    # validate prediction file
    if args.submission_file is None:
        invalid_reasons.append(
            'Expected FileEntity type but found ' + args.entity_type
        )
    else:
        # decompress submission file
        pred_fs = _decompress_file(args.submission_file)
        true_pred_fs = [f'{file_prefix}_{c}_{p}_imputed.csv'
                        for p in ds_props for c in conditions]
        # check if all required data exists
        diff = list(set(true_pred_fs) - set(pred_fs))
        if diff:
            invalid_reasons.append('File not found : ' + '", "'.join(diff))

    if not invalid_reasons:
        if args.question == '1':
            # validate predicted data
            scRNA_res = _validate_scRNA(true_ds_fs, true_pred_fs)
            invalid_reasons.extend(scRNA_res)
        else:
            # TODO: add validation function for scATACseq
            pass

    validate_status = 'INVALID' if invalid_reasons else 'VALIDATED'
    result = {'submission_errors': '\n'.join(invalid_reasons),
              'submission_status': validate_status}
    with open(args.results, 'w') as o:
        o.write(json.dumps(result))


if __name__ == "__main__":
    main()
