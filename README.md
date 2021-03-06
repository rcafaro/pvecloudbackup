# PVECloudBackup: Differential, cloud-based backups for Proxmox VE
Differential and cloud backup scripts for Proxmox VE

This script uses the xdelta3 library and vzdump hook script to automatically generate weekly differential backups using Proxmox VE.
Differential backups are small and easier to restore than incremental backups, since only the last full backup + the differential backup of the desired day are needed.

I tried other solutions available online such as [Ayufan's](https://github.com/ayufan/pve-patches) UI-integrated solution but utlimately I decided to steer away from patching the PVE code and going with something that I could customize to my liking.

This approach allows you to select full or differential backup simply by opting for compression (full) or no-compression (differential) on the PVE backup UI. 

**THIS VERSION HANDLES LOCAL DIFFERENTIAL BACKUPS. FUTURE VERSIONS WILL ALSO COPY THESE OVER TO A CLOUD PROVIDER OF CHOICE (WIP)**

## **To install:**

install dependencies: 

    apt install xdelta3 rename git

clone repository to /root/pvecloudbackup on PVE node. On a farm, deploy to all nodes where backups run

Then:

    echo "script: /root/pvecloudbackup/vzdump-hook-script.pl" >> /etc/vzdump.conf
    chmod +x ~/pvecloudbackup/vzdump-hook-script.pl


## **To run backups:**

Simply configure your backups on PVE to run **without compression**. This is required for proper xdelta3 operation. 
Don't worry - you'll still be saving space since differentials are so much smaller.
When you wish to revert to regular PVE/vzdump behavior, simply select a compressed format and the differential job will not run. 

Backup retention period is configurable in the script ($max variable). Day for full backup is configurable with $full_backup_day variable.


## **Restoring backups**

While *full* weekly backups are natively restorable using the proxmox UI, restoring a differential backup will require you first recreate a full backup from the delta file, and then restore using proxmox UI.


That would be something like: 
  1. xdelta3 -d -s "grooupN.full.vma" "groupN.xdelta.vma" "name_of_target_to_restore" 
  2. perform normal restore in proxmox for "*name_of_target_to_restore*"
  


## **Credits:**

This is largely based off these awesome sources:
* https://github.com/jmacd/xdelta by Joshua McDonald
* https://forum.proxmox.com/threads/new-feature-on-pve-console-differential-backup-for-qemu-vms.19098/ - by Daniel Mash
