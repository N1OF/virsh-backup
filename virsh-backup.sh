#virsh-backup.sh
#Private Open Source License 1.0
#Copyright 2024 Scott Sheets

#https://github.com/DomTheDorito/Private-Open-Source-License

#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the 
#Software without limitation the rights to personally use, copy, modify, distribute,
#and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

#2. The source code shall not be used for commercial purposes, including but not limited to sale of the Software, or use in products 
#intended for sale, unless express writen permission is given by the source creator.

#3. Attribution to source work shall be made plainly available in a reasonable manner.

#THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
#FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN 
#AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#THIS LICENSE MAY BE UPDATED OR REVISED, WITH NOTICE ON THE POS LICENSE REPOSITORY.

#!/bin/bash

# Configuration
BACKUP_DIR="/mnt/backups"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$BACKUP_DIR/backup_log_$DATE.log"
ERROR_LOG_FILE="$BACKUP_DIR/backup_error_log_$DATE.log"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Log start time
echo "Backup started at $DATE" > "$LOG_FILE"
echo "Backup started at $DATE" > "$ERROR_LOG_FILE"

# Get the list of running VMs
VM_LIST=$(virsh list --name)
if [ -z "$VM_LIST" ]; then
    echo "No running VMs found." | tee -a "$LOG_FILE"
    exit 1
fi

for VM in $VM_LIST; do
    echo "Processing VM: $VM" | tee -a "$LOG_FILE"

    # Shut down the VM
    echo "  Shutting down VM: $VM" | tee -a "$LOG_FILE"
    if ! virsh shutdown "$VM" >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"; then
        echo "    Failed to shut down VM: $VM" | tee -a "$ERROR_LOG_FILE"
        continue
    fi

    # Wait for the VM to completely shut down
    echo "  Waiting for VM to shut down: $VM" | tee -a "$LOG_FILE"
    while true; do
        VM_STATE=$(virsh list --state-shutoff --name | grep "$VM")
        if [ -n "$VM_STATE" ]; then
            echo "    VM $VM has shut down." | tee -a "$LOG_FILE"
            break
        fi
        echo "    Waiting for VM $VM to shut down..." | tee -a "$LOG_FILE"
        sleep 10
    done

    # Get the list of disk devices and their file paths
    DISK_INFO=$(virsh domblklist "$VM" --details | awk '/disk/ {print $1, $4}')
    if [ -z "$DISK_INFO" ]; then
        echo "  No disk devices found for VM $VM" | tee -a "$LOG_FILE"
        # Skip to the next VM if no disks are found
        continue
    fi

    while read -r DISK DEVICE_PATH; do
        # Generate backup file name
        BACKUP_FILE="$BACKUP_DIR/${VM}_${DISK}_$DATE.qcow2"

        echo "  Creating backup for disk: $DEVICE_PATH to $BACKUP_FILE" | tee -a "$LOG_FILE"

        # Use qemu-img to copy the disk image
        if qemu-img convert -f qcow2 -O qcow2 "$DEVICE_PATH" "$BACKUP_FILE" >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"; then
            echo "    Backup successful: $BACKUP_FILE" | tee -a "$LOG_FILE"
        else
            echo "    Backup failed: $BACKUP_FILE" | tee -a "$ERROR_LOG_FILE"
        fi
    done <<< "$DISK_INFO"

    # Restart the VM
    echo "  Restarting VM: $VM" | tee -a "$LOG_FILE"
    if ! virsh start "$VM" >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"; then
        echo "    Failed to restart VM: $VM" | tee -a "$ERROR_LOG_FILE"
    fi
done

# Log end time
echo "Backup ended at $(date +"%Y-%m-%d_%H-%M-%S")" | tee -a "$LOG_FILE"
