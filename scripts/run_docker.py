"""Run training synthetic docker models"""
from __future__ import print_function
import argparse
import getpass
import glob
import os
import tarfile
import time
import json

import docker
import subprocess
import synapseclient


def get_last_lines(log_filename, n=5):
    """Get last N lines of log file (default=5)."""
    lines = 0
    with open(log_filename, "rb") as f:
        try:
            f.seek(-2, os.SEEK_END)
            while lines < n:
                f.seek(-2, os.SEEK_CUR)
                if f.read(1) == b"\n":
                    lines += 1
        except OSError:
            f.seek(0)
        last_lines = f.read().decode()
    return last_lines


def create_log_file(log_filename, log_text=None, mode="w"):
    """Create log file"""
    with open(log_filename, mode) as log_file:
        if log_text is not None:
            if isinstance(log_text, bytes):
                log_text = log_text.decode("utf-8")
            log_file.write(log_text.encode("ascii", "ignore").decode("ascii"))
        else:
            log_file.write("No Logs")


def store_log_file(syn, log_filename, parentid, store=True):
    """Store log file"""
    statinfo = os.stat(log_filename)
    if statinfo.st_size > 0:
        # If log file is larger than 50Kb, only save last 10 lines.
        if statinfo.st_size/1000.0 > 50:
            log_tail = get_last_lines(log_filename, n=10)
            create_log_file(log_filename, log_tail)
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


def main(syn, args):
    """Run docker model"""
    if args.docker_status == "INVALID":
        raise Exception("Docker image is invalid")

    # The new toil version doesn't seem to pull the docker config file from
    # .docker/config.json...
    # client = docker.from_env()
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')

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
    input_dir = args.input_dir

    # Assign different resources limit for different questions
    # allow three submissions at a time
    docker_mem = "160g" if args.question == "1" else "20g"
    docker_cpu = 20000000000 if args.question == "1" else 10000000000
    docker_runtime_quot = 21600 if args.public_phase == "public" else 43200
    pred_file_suffix = "*_imputed.csv" if args.question == "1" else "*.bed"

    print("mounting volumes")
    # create a local volume and set size limit
    output_volume_name = f"{args.submissionid}-output"
    output_volume = client.volumes.create(name=output_volume_name,
                                          driver='local',
                                          driver_opts={"size": "120g"})
    # set volumes used to mount
    input_mount = [input_dir, "input"]
    output_mount = [output_volume_name, "output"]
    volumes = [f"{input_mount[0]}:/{input_mount[1]}:ro",
               f"{output_mount[0]}:/{output_mount[1]}:rw"]

    # Look for if the container exists already, if so, reconnect
    print("checking for containers")
    container = None
    docker_errors = None  # errors raised from docker container
    sub_errors = []  # friendly errors sent to participants about failed submission

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
        start_time = time.time()
        time_elapsed = 0
        try:
            container = client.containers.run(docker_image,
                                              detach=True,
                                              volumes=volumes,
                                              name=args.submissionid,
                                              network_disabled=True,
                                              mem_limit=docker_mem,
                                              nano_cpus=docker_cpu,
                                              storage_opt={"size": "120g"})
        except docker.errors.APIError as err:
            remove_docker_container(args.submissionid)
            docker_errors = str(err) + "\n"

    print("creating logfile")
    # Create the logfile
    log_filename = args.submissionid + "_log.txt"
    # Open log file first
    open(log_filename, 'w').close()

    # If the container doesn't exist,
    # there are no logs to write out and no container to remove
    if container is not None:
        # Check if container is still running
        while container in client.containers.list():
            # monitor the time elapsed
            # if it exceeds the runtime quota, stop the container
            time_elapsed = time.time() - start_time
            if time_elapsed > docker_runtime_quot:
                sub_errors.append(
                    f"Submission time limit of {int(docker_runtime_quot/3600)}h reached.")
                container.stop()
                break

            log_text = container.logs()
            create_log_file(log_filename, log_text=log_text)
            store_log_file(syn, log_filename, args.parentid, store=args.store)
            time.sleep(60)

        # Must run again to make sure all the logs are captured
        log_text = container.logs()
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid, store=args.store)
        # copy the prediction dir from model container to working dir before removed
        try:
            subprocess.check_call(
                ["docker", "cp", f"{args.submissionid}:/{output_mount[1]}", "."])
        except subprocess.CalledProcessError as err:
            docker_errors = str(err) + "\n"
            container.stop()

        container.remove()

    statinfo = os.stat(log_filename)

    # if not succesfully run the docker container or no log
    if statinfo.st_size == 0:
        create_log_file(log_filename, log_text=docker_errors)
        store_log_file(syn, log_filename, args.parentid, store=args.store)

    print("finished training")
    # try to remove image and volume
    remove_docker_image(docker_image)
    output_volume.remove()

    # check if any expected file pattern exist
    if glob.glob(os.path.join(output_mount[1], pred_file_suffix)):
        tar(output_mount[1], "predictions.tar.gz")
        sub_status = "VALIDATED"
    else:
        sub_status = "INVALID"
        sub_errors.append(
            f"It seems error encountered while running your Docker container and "
            f"no '{pred_file_suffix}' file written to '/{output_mount[1]}' folder.")

    with open("results.json", "w") as out:
        out.write(json.dumps({
            'submission_status': sub_status,
            'submission_errors': "\n".join(sub_errors)
        }))


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
    parser.add_argument("--public_phase", required=True,
                        help="Public leaderborder phase")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("--store", action='store_true',
                        help="to store logs")
    parser.add_argument("--parentid", required=True,
                        help="Parent Id of submitter directory")
    parser.add_argument("--docker_status", required=True,
                        help="Docker image status")
    args = parser.parse_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()
    main(syn, args)
