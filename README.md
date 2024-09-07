# virsh-backup
Bash script used to pause KVM Virtual Machines, backup the .qcow2 files to a location of your choice, then restart the VM.
This script assumes you can afford downtime on your machines, so this is recommended for environments where the machines can be shut down.
Depending on the size of your VM Virtual Hard Disks (.qcow2 files), and where you are storing them, will dictate how long your machines will be down.

The script will create the backup directory you specify in line 27 if it does not exist already, and will start a log file, as well as a verbose error file in the same directory. The script will call to virsh to pull a list of current domains (VMs), as well as whatever disks are associated with them. For each domain, virsh will shut it down, then poll every 10 seconds until virsh confirms it has been shut down. This will release the write lock on the .qcow2 file, which will allow it to be manipulated. qemu-img will do a 1:1 .qcow2 conversion, and write the second file to the backup directory you specify. Once the write is completed, virsh will call to power the domain back on.

**WARNING**

I have only tested this on VMs using simple .qcow2 VHD files, I cannot say if it will ignore attached block devices that are not .qcow2. This also will poll and backup EVERY VM DOMAIN in your virsh hypervisor. For most standard KVM instances using a single (or more) .qcow2 VHD files, this should work fine.

Requirements:
Set the "BACKUP_DIR" variable to a path of your choosing, that your user account will have write access to. Mounted drives will work as well.

Performance:
I have 5 VMs backing up to a mounted network drive via SSHFS. Through a 1GB connection writing to a RAID1 backup machine, it took about 15 minutes to write ~40 GB of .qcow2 VHD backups. 

I wrote this for my homelab setup and have this scheduled as a cron job to run in the middle of the night, as my network/services have little to no use at that time. Would not recommend in mission critical enviornments. Use at your own risk. 

Dry Run:
I have included a second script that can be ran as a "Dry Run". This will simulate all of the steps of the regular script without actually running the commands. This will output to the console, as well as to the log file all steps with "(Dry Run)" at the beginning.

Experimentation:
If for whatever reason you would like to store your backups under a different type of VHD, for example, as a VHD for quick Hyper-V restorations, VMDK for VMware, or even a raw .img file, you may change the arguments passed to qemu-img on line 83. For example, to output to a VMDK, change the -O parameter to VMDK, and change the variable in line 78 to end in .vmdk after the $DATE placeholder.
