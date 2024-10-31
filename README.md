# Backup Script Documentation

## Overview

This Bash script performs backups using `rsync` for various directories to a remote storage location. It manages the backup process, logs the progress and errors, and handles cleanup of old files in a designated trash directory.

## Workflow

- **Initialization**: Clears the error log and checks for the trash directory and backup volumes.
- **Mounting**: Attempts to mount the trash and backup directories. If mounting fails, the script exits.
- **Disk Space Check**: Calculates total disk space and compares it with the required minimum size.
- **Old Trash Cleanup**: Deletes files older than the specified age from the trash directory.
- **Backup Process**: For each defined job:
  - Checks if the source directory exists and if its size meets the minimum requirement.
  - Performs the backup using `rsync` and logs the output.
  - Records any errors encountered during the backup.
- **Cleanup**: Removes temporary log files and marks the end of the backup process.

## Logging

- Logs progress and errors in the specified log files.
- Each job's outcome is recorded in the main log file (`LOG_FILE`), while errors are logged in the `ERRORS` file.


## Dependencies

- **Bash**: The script is written in Bash and requires a compatible shell environment.
- **rsync**: This tool is used for file synchronization and must be installed on the system.
- **bc**: Used for arbitrary precision calculations, needed for size comparisons.
- **du**: Used to check the size of directories.
- **find**: Utilized for cleaning up old files and empty directories.

Ensure that the script is run with appropriate permissions, as it may require `sudo` for mounting volumes.

## Configuration

Before running the script, configure the following parameters at the top of the script:

### Parameters

- `NUMBERVOLUMES`: Number of volumes in the mergerfs disk (default: `4`).
- `MOUNT_PREFIX`: Prefix for mount points in mergerfs disks (default: `/mnt/disk-B`).
- `BACKUPDIR`: Directory where backups are stored (default: `/mnt/COLDSTORAGE`).
- `BACKUPTESTFILE`: A test file ***you have to create*** to verify if the backup directory is mounted (default: `$BACKUPDIR/.BACKUP`).
- `BACKUPSIZE`: Minimum size in TB required for the backup volume (default: `13`).
- `TRASHDIR`: Path to where deleted files will be sent (default: `/mnt/TRASH/`).
- `TRASHAGE`: Number of days to keep files in the trash directory (default: `90`).
- `TRASHTESTFILE`: A test file ***you have to create*** to verify if the trash directory is mounted (default: `$TRASHDIR/.TRASH`).
- `LOG_FILE`: Path to the main log file for backups (default: `/DATA/log/rsync/log-delete.txt`).
- `TEMP_LOG_FILE`: Path to the temporary log file (default: `/DATA/log/rsync/logtemp-delete.txt`).
- `TEST_LOG_FILE`: Path to the test log file (default: `/DATA/log/rsync/testlog-delete.txt`).
- `TEST_TEMP_LOG_FILE`: Path to the temporary test log file (default: `/DATA/log/rsync/testlogtemp-delete.txt`).
- `ERRORS`: Log for recording errors (default: `/DATA/log/rsync/errors-delete.txt`).

### Backup Jobs

Define the backup jobs in the `JOBS` array, where each job is formatted as follows:

"source_directory|destination_directory|job_name|min_size(MB)"

For example:

```bash
JOBS=(
    "source_dir_1|destination_dir_1|Job 1|0"
    "source_dir_2|destination_dir_2|Job 2|1"
)
```
## Usage

- **Edit the Configuration**: Update the parameters and jobs as needed in the script.

- **Make the Script Executable**:
  ```bash
  chmod +x /path/to/rsync-backup.sh
