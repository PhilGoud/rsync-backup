#!/bin/bash

# This script performs backups using rsync for various directories to a remote storage.
# It logs the progress and errors.

# Parameters
NUMBERVOLUMES=4 # Number of volumes in mergerfs disk
MOUNT_PREFIX="/mnt/disk-B" # Prefix for mount points in mergerfs disks
BACKUPDIR="/mnt/COLDSTORAGE" # Directory where backups are stored
BACKUPTESTFILE="$BACKUPDIR/.BACKUP" # File to test in the backup folder
BACKUPSIZE=13 # Minimum size in TB for backup volume
TRASHDIR="/mnt/TRASH/" # Path to where deleted files will be sent
TRASHAGE="90" # Number of days to keep files in the trash directory
TRASHTESTFILE="$TRASHDIR/.TRASH" # File to test in the trash folder

LOG_FILE="/DATA/log/rsync/log-delete.txt"  # Path to the main log file
TEMP_LOG_FILE="/DATA/log/rsync/logtemp-delete.txt"  # Path to the temporary log file
TEST_LOG_FILE="/DATA/log/rsync/testlog-delete.txt"  # Path to the test log file
TEST_TEMP_LOG_FILE="/DATA/log/rsync/testlogtemp-delete.txt"  # Path to the temporary test log file
ERRORS="/DATA/log/rsync/errors-delete.txt" # Log for errors

# Directories, destinations, and names in the format: "source_directory|destination_directory|name|min-size(MB)"
JOBS=(
    "source_dir_1|destination_dir_1|Job 1|0"
    "source_dir_2|destination_dir_2|Job 2|1"
    "source_dir_3|destination_dir_3|Job 3|50"
    "source_dir_4|destination_dir_4|Job 4|5000"
    # Add more jobs as needed
)

# INITIALISATION
echo "-------------INITIALISATION-------------"
NUMBER_OF_DIRECTORIES=${#JOBS[@]} # Calculate the number of directories
echo "" > "$ERRORS" # Clear errors log
check=0 # Initialize check counter

# Mounting trash volume
echo "Mounting Trash volume"
sudo mount "$TRASHDIR" &> /dev/null
sleep 10 

if [ ! -f "$TRASHTESTFILE" ]; then
    echo "TRASH NOT MOUNTED, TEST FILE NOT FOUND : CANCELLED"
    exit 1 # Exit if trash is not mounted
else
    echo "TRASH DISK CHECK PASSED"
    echo ""
fi

# Mounting COLDSTORAGE volumes
echo "Mounting Individual backup volumes"

# Loop through each volume number from 1 to NUMBERVOLUMES
for ((i=1; i<=NUMBERVOLUMES; i++)); do
   mount_point="${MOUNT_PREFIX}${i}" # Define mountpoint
   sudo mount "$mount_point" # Attempt to mount the device

   if [ $? -eq 0 ]; then
       echo "Mounted $mount_point successfully."
   else
       echo "Failed to mount $mount_point."
       exit 1 # Exit if mounting fails
   fi
done

# Mounting COLDSTORAGE itself
echo "Mounting MERGERFS VOLUME"
sudo mount "$BACKUPDIR"

# Check for test file
if [ ! -f "$BACKUPTESTFILE" ]; then
    echo "BACKUP NOT MOUNTED, TEST FILE NOT FOUND : CANCELLED"
    exit 1 # Exit if backup is not mounted
else
    echo "BACKUP DISK CHECK PASSED TEST FILE"
    echo ""
fi

# Get total disk space in kilobytes (use `df` and `awk` to extract the value)
total_space_kb=$(df --block-size=1K "$BACKUPDIR" | awk 'NR==2 {print $2}')

# Convert total disk space from kilobytes to terabytes (1TB = 1,099,511,627,776 bytes)
total_space_tb=$(echo "scale=2; $total_space_kb / (1024*1024*1024)" | bc)

# Check if the total space is under the required size
if (( $(echo "$total_space_tb < $BACKUPSIZE" | bc -l) )); then
    echo "Disk space is under $BACKUPSIZE TB. Exiting the script."
    exit 1 # Exit if space is insufficient
fi

echo "Disk space is sufficient: $total_space_tb TB when $BACKUPSIZE TB is required"

echo "-------------EMPTY OLD TRASH-------------"
# Remove old files (never folders) from trash
echo "DELETING FILES OLDER THAN $TRASHAGE DAYS"
find "$TRASHDIR*" -mtime +"$TRASHAGE" -exec rm {} \;
echo "DELETING EMPTY DIRECTORIES"
find "$TRASHDIR" -type d -empty -delete
echo "DELETE COMPLETE"
echo ""

# Start of the backup process
echo "📦 BACKUP RSYNC-DELETE 🔄" > "$LOG_FILE"
echo "Start at $(date +"%H:%M:%S")" >> "$LOG_FILE"

convert_bytes() {
    local bytes=$1

    # Check if input is empty or non-numeric
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "error-invalid"
        return 1
    fi

    # Check if size is zero
    if [[ "$bytes" -eq 0 ]]; then
        echo "0 bytes"
        return
    fi

    # Check if the number of digits exceeds 50
    if [[ "${#bytes}" -gt 50 ]]; then
        echo "error-toolong"
        return 1
    fi

    # Convert bytes to a readable format
    local unit=""
    local value=0

    if (( bytes >= 1073741824 )); then
        unit="GB"
        value=$((bytes / 1073741824))
    elif (( bytes >= 1048576 )); then
        unit="MB"
        value=$((bytes / 1048576))
    elif (( bytes >= 1024 )); then
        unit="KB"
        value=$((bytes / 1024))
    else
        echo "$bytes bytes"
        return
    fi

    # Output rounded value and unit
    printf "%.2f %s" "$value" "$unit"
}

# Backup loop through jobs
for JOB in "${JOBS[@]}"; do
    # Splitting the job into source, destination, name, and min-size
    IFS='|' read -r source dest name min_size <<< "$JOB"

    # Check if the source directory exists
    if [[ ! -d "$source" ]]; then
        echo "Source directory $source does not exist. Skipping..."
        continue
    fi

    # Get size of source directory
    src_size=$(du -sb "$source" | awk '{print $1}')
    # Check size against minimum size
    min_size_bytes=$(echo "$min_size * 1048576" | bc)

    if (( $(echo "$src_size < $min_size_bytes" | bc -l) )); then
        echo "$name ($source) is smaller than the minimum size of $(convert_bytes "$min_size_bytes"). Skipping..."
        continue
    fi

    # Perform the backup
    echo "Starting backup for $name..."

    rsync -av --delete "$source" "$dest" &>> "$TEMP_LOG_FILE"

    if [ $? -eq 0 ]; then
        echo "Backup for $name completed successfully."
    else
        echo "Backup for $name failed. Check the log for details."
        echo "Backup for $name failed." >> "$ERRORS"
    fi

    # Clear temporary log after each job
    echo "" > "$TEMP_LOG_FILE"
done

# Backup completed
echo "Backup process completed."
echo "End at $(date +"%H:%M:%S")" >> "$LOG_FILE"

# Clean up temporary files
if [ -f "$TEMP_LOG_FILE" ]; then
    rm "$TEMP_LOG_FILE"
fi

# End of script
