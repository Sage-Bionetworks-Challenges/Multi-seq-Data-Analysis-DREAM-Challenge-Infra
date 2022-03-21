#!/usr/bin/env python
"""Validation script for scRNA-seq signal correction.
Predictions file must be a zipped archive of imputed count files.
Each imputed count file must have a correct file format:
(pac_expId_ds_prop_imputed.csv).
"""

import argparse
import json
import pandas as pd
import os
import tarfile
import zipfile


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-r", "--results", required=True,
                        help="validation results")
    parser.add_argument("-e", "--entity_type", required=True,
                        help="synapse entity type downloaded")
    parser.add_argument("-s", "--submission_file", help="Submission file")
    parser.add_argument("-c", "--condition", required=True, nargs='+',
                        help="Experiment condition")
    parser.add_argument("-p", "--proportion", required=True, nargs='+',
                        help="Downsampling proportion")
    parser.add_argument("-x", "--file_prefix", required=True,
                        help="Prefix of filename")
    parser.add_argument("-q", "--question", required=True,
                        help="Challenge question")
    return parser.parse_args()


def _filter_files(members):
    """Filter out non-csv files in zip file."""
    filenames = filter(lambda file: file.endswith(".csv"), members)
    filenames = list(filenames)
    return filenames


def unzip_file(f):
    """Untar or unzip file."""
    names = []
    dfs = []
    if zipfile.is_zipfile(f):
        with zipfile.ZipFile(f) as zip_ref:
            members = zip_ref.namelist()
            members = _filter_files(members)
            if members:
                for member in members:
                    # save basename as file names used to validate
                    # in case root dir is zipped
                    names.append(os.path.basename(member))
                    file = zip_ref.open(member)
                    df = pd.read_csv(file, index_col=0)
                    dfs.append(df)
    elif tarfile.is_tarfile(f):
        with tarfile.open(f) as zip_ref:
            members = zip_ref.getnames()
            members = _filter_files(members)
            if members:
                for member in members:
                    names.append(os.path.basename(member))
                    file = zip_ref.extractfile(member)
                    df = pd.read_csv(file, index_col=0)
                    dfs.append(df)
    return {"names": names, "files": dfs}


def get_dim_name(df):
    """Get all row names and column names of df"""
    out = {"rownames": list(df.index),
           "colnames": list(df.columns.values)}
    return out


def validate_scRNA(ds_files, pred_files, pred_filenames):
    """validate on scRNA-seq data"""
    invalid_reasons = []
    # get all rownames and colnames of downsampled data
    ds_names = []
    for ds_f in ds_files:
        ds_names.append(get_dim_name(ds_f))

    # validate each prediction file
    for index, pred_df in enumerate(pred_files):
        file_name = pred_filenames[index]
        # check if all genes/cells exist in predictions
        pred_names = get_dim_name(pred_df)
        cp1 = set(pred_names["rownames"]).issubset(
            ds_names[index]["rownames"])
        cp2 = set(pred_names["colnames"]).issubset(
            ds_names[index]["colnames"])
        if not (cp1 and cp2):
            invalid_reasons.append(
                file_name + ": Do not contain all genes or cells")
        else:
            # check if all values are numeric
            cp3 = pred_df.apply(lambda s: pd.to_numeric(
                s, errors='coerce').isnull().any())
            if cp3.any():
                invalid_reasons.append(
                    file_name + ": Not all values are numeric")
            # check if all values are >= 0
            elif (pred_df < 0).any().any():
                invalid_reasons.append(
                    file_name + ": Negative value is not allowed")
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
    true_ds_fs = [file_prefix + "_" + c + "_" + p + ".csv"
                  for p in ds_props for c in conditions]
    # downsampled files should be copied to working dir
    diff = list(set(true_ds_fs) - set(os.listdir(".")))
    if diff:
        invalid_reasons.append("File not found : " + "', '".join(diff))

    # validate prediction file
    if args.submission_file is None:
        invalid_reasons.append(
            'Expected FileEntity type but found ' + args.entity_type
        )
    else:
        pred_fs = unzip_file(args.submission_file)
        true_pred_fs = [file_prefix + "_" + c + "_" + p + "_imputed.csv"
                        for p in ds_props for c in conditions]
        # check if all required data exists
        diff = list(set(true_pred_fs) - set(pred_fs["names"]))
        if diff:
            invalid_reasons.append("File not found : " + "', '".join(diff))

    if not invalid_reasons:
        if args.question == "1A":
            # read downsampled data
            ds_df = []
            for ds_f in true_ds_fs:
                ds_df.append(pd.read_csv(ds_f, index_col=0))
            # validate predicted data
            scRNA_res = validate_scRNA(
                ds_df, pred_fs["files"], pred_fs["names"])
            invalid_reasons.extend(scRNA_res)
        elif args.question == "1B":
            # TODO: add validation function for scATACseq when reference script is provided
            pass

    validate_status = "INVALID" if invalid_reasons else "VALIDATED"
    result = {'submission_errors': "\n".join(invalid_reasons),
              'submission_status': validate_status}
    with open(args.results, 'w') as o:
        o.write(json.dumps(result))


if __name__ == "__main__":
    main()
