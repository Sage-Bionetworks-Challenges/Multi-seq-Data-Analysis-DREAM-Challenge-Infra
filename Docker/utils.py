import tarfile
import zipfile
import shutil
import os


def filter_files(members, type='tar'):
    """Filter out non-csv files in zip file."""
    if type == "tar":
        new_members = filter(
            lambda member: member.name.endswith('.csv'), members)
    else:
        new_members = filter(lambda member: member.endswith('.csv'), members)
    new_members = list(new_members)
    return new_members


def decompress_file(f):
    """Untar or unzip file."""
    names = []
    # decompress zip file
    if zipfile.is_zipfile(f):
        with zipfile.ZipFile(f) as zip_ref:
            members = zip_ref.namelist()
            members = filter_files(members, type='zip')
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
            members = filter_files(members)
            if members:
                for member in members:
                    # skip the folder names
                    member.name = os.path.basename(member.name)
                    tar_ref.extract(member)
                    names.append(member.name)
    return names
