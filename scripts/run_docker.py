"""Run training synthetic docker models"""
from __future__ import print_function
import argparse
import getpass
import os
import tarfile
import time

import docker
import subprocess
import synapseclient


def create_log_file(log_filename, log_text=None):
    """Create log file"""
    with open(log_filename, 'w') as log_file:
        if log_text is not None:
            if isinstance(log_text, bytes):
                log_text = log_text.decode("utf-8")
            log_file.write(log_text.encode("ascii", "ignore").decode("ascii"))
        else:
            log_file.write("No Logs")


def store_log_file(syn, log_filename, parentid, store=True):
    """Store log file"""
    statinfo = os.stat(log_filename)
    if statinfo.st_size > 0 and statinfo.st_size/1000.0 <= 50:
        ent = synapseclient.File(log_filename, parent=parentid)
        if store:
            try:
                syn.store(ent)
            except synapseclient.exceptions.SynapseHTTPError as err:
                print(err)
        else:
            subprocess.check_call(
                ["docker", "cp", os.path.abspath(log_filename),
                 "logging:/logging"]
            )


def remove_docker_container(container_name):
    """Remove docker container"""
    client = docker.from_env()
    try:
        cont = client.containers.get(container_name)
        cont.stop()
        cont.remove()
    except Exception:
        print("Unable to remove container")


def remove_docker_image(image_name):
    """Remove docker image"""
    client = docker.from_env()
    try:
        client.images.remove(image_name, force=True)
    except Exception:
        print("Unable to remove image")


def prune_docker_volumes():
    """Remove unused docker volumes"""
    client = docker.from_env()
    try:
        client.volumes.prune()
    except Exception:
        print("Unable to clean volumes")


def tar(directory, tar_filename):
    """Tar all files in a directory

    Args:
        directory: Directory path to files to tar
        tar_filename:  tar file path
    """
    with tarfile.open(tar_filename, "w") as tar_o:
        tar_o.add(directory)
    # TODO: Potentially add code to remove all files that were zipped.


def untar(directory, tar_filename):
    """Untar a tar file into a directory

    Args:
        directory: Path to directory to untar files
        tar_filename:  tar file path
    """
    with tarfile.open(tar_filename, "r") as tar_o:
        tar_o.extractall(path=directory)


# def determine_volume_dir(input_dirs: list):
#     client = docker.from_env()
#     containers = client.containers.list(
#         filters={"status": "running", "name": "\d{7}"})
#     if containers:
#         volume_dir = input_dirs[0]
#     else:
#         try:
#             mounted_dirs = [c.labels["mounted_dir"] for c in containers]
#             available_dirs = list(set(input_dirs) - set(mounted_dirs))
#             volume_dir = available_dirs[0]
#         except Exception:
#             print("Unable to find available input directories")
#     return volume_dir


def main(syn, args):
    """Run docker model"""
    if args.status == "INVALID":
        raise Exception("Docker image is invalid")

    # The new toil version doesn't seem to pull the docker config file from
    # .docker/config.json...
    # client = docker.from_env()
    client = docker.DockerClient(
        base_url='unix://var/run/docker.sock', timeout=600)

    config = synapseclient.Synapse().getConfigFile(
        configPath=args.synapse_config
    )
    authen = dict(config.items("authentication"))
    client.login(username=authen['username'],
                 password=authen['password'],
                 registry="https://docker.synapse.org")
    # dockercfg_path=".docker/config.json")

    print(getpass.getuser())

    # Add docker.config file
    docker_image = args.docker_repository + "@" + args.docker_digest

    # These are the volumes that you want to mount onto your docker container
    # input_dir = determine_volume_dir(
    #     [f'{args.input_dir}{i}' for i in range(1, 3)])
    input_dir = args.input_dir
    output_dir = os.getcwd()

    # Assign different memory limit for different questions
    # allow three submissions at a time
    docker_mem = "160g" if args.question == "1" else "20g"
    docker_cpu = 20000000000 if args.question == "1" else 10000000000

    print("mounting volumes")
    # These are the locations on the docker that you want your mounted
    # volumes to be + permissions in docker (ro, rw)
    # It has to be in this format '/output:rw'
    mounted_volumes = {output_dir: '/output:rw',
                       input_dir: '/data:ro'}
    # All mounted volumes here in a list
    all_volumes = [output_dir, input_dir]
    # Mount volumes
    volumes = {}
    for vol in all_volumes:
        volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0],
                        'mode': mounted_volumes[vol].split(":")[1]}

    # Look for if the container exists already, if so, reconnect
    print("checking for containers")
    container = None
    errors = None
    for cont in client.containers.list(all=True):
        if args.submissionid in cont.name:
            # Must remove container if the container wasn't killed properly
            if cont.status == "exited":
                cont.remove()
            else:
                container = cont
    # If the container doesn't exist, make sure to run the docker image
    if container is None:
        # Run as detached, logs will stream below
        print("running container")
        try:
            container = client.containers.run(docker_image,
                                              detach=True,
                                              #   labels={
                                              #       "mounted_dir": input_dir},
                                              volumes=volumes,
                                              name=args.submissionid,
                                              network_disabled=True,
                                              mem_limit=docker_mem,
                                              #   nano_cpus=docker_cpu,
                                              stderr=True)
        except docker.errors.APIError as err:
            remove_docker_container(args.submissionid)
            errors = str(err) + "\n"

    print("creating logfile")
    # Create the logfile
    log_filename = args.submissionid + "_log.txt"
    # Open log file first
    open(log_filename, 'w').close()

    # If the container doesn't exist, there are no logs to write out and
    # no container to remove
    print(container)
    if container is not None:
        print(1)
        # Check if container is still running
        while container in client.containers.list():
            log_text = container.logs()
            create_log_file(log_filename, log_text=log_text)
            store_log_file(syn, log_filename, args.parentid, store=args.store)
            time.sleep(60)
        # Must run again to make sure all the logs are captured
        print(2)
        log_text = container.logs()
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid, store=args.store)
        # Remove container and image after being done
        container.remove()
        print(3)

    statinfo = os.stat(log_filename)

    if statinfo.st_size == 0:
        create_log_file(log_filename, log_text=errors)
        store_log_file(syn, log_filename, args.parentid, store=args.store)

    print("finished training")
    # Try to remove the image
    remove_docker_image(docker_image)

    output_folder = os.listdir(output_dir)
    if not output_folder:
        raise Exception("No 'predictions.tar.gz' file written to /output, "
                        "please check inference docker")
    elif "predictions.tar.gz" not in output_folder:
        raise Exception("No 'predictions.tar.gz' file written to /output, "
                        "please check inference docker")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id")
    parser.add_argument("-p", "--docker_repository", required=True,
                        help="Docker repository")
    parser.add_argument("-d", "--docker_digest", required=True,
                        help="Docker digest")
    parser.add_argument("-q", "--question", required=True,
                        help="Challenge question")
    parser.add_argument("-i", "--input_dir", required=True,
                        help="Input directory of downsampled data")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("--store", action='store_true',
                        help="to store logs")
    parser.add_argument("--parentid", required=True,
                        help="Parent Id of submitter directory")
    parser.add_argument("--status", required=True, help="Docker image status")
    args = parser.parse_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()
    main(syn, args)
