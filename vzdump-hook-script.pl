#!/usr/bin/perl -w
#author: rcafaro @ GitHub

# Example hook script for vzdump (--script option)
# This can also be added as a line in /etc/vzdump.conf
# e.g. 'script: /usr/local/bin/vzdump-hook-script.pl'


use strict;

print "HOOK: " . join (' ', @ARGV) . "\n";

my $phase = shift;

if ($phase eq 'job-start' ||
    $phase eq 'job-end'  ||
    $phase eq 'job-abort') {

    my $dumpdir = $ENV{DUMPDIR};

    my $storeid = $ENV{STOREID};

    print "HOOK-ENV: dumpdir=$dumpdir;storeid=$storeid\n";

    # do what you want

} elsif ($phase eq 'backup-start' ||
	 $phase eq 'backup-end' ||
	 $phase eq 'backup-abort' ||
	 $phase eq 'log-end' ||
	 $phase eq 'pre-stop' ||
	 $phase eq 'pre-restart' ||
	 $phase eq 'post-restart') {

    my $mode = shift; # stop/suspend/snapshot

    my $vmid = shift;

    my $vmtype = $ENV{VMTYPE}; # lxc/qemu

    my $dumpdir = $ENV{DUMPDIR};

    my $storeid = $ENV{STOREID};

    my $hostname = $ENV{HOSTNAME};

    # target is only available in phase 'backup-end'
    my $target = $ENV{TARGET};

    # logfile is only available in phase 'log-end'
    my $logfile = $ENV{LOGFILE};

    print "HOOK-ENV: vmtype=$vmtype;dumpdir=$dumpdir;storeid=$storeid;hostname=$hostname;target=$target;logfile=$logfile\n";

    # Gerar backup diferencial a partir do ultimo full SEMANAL
    #baseado em https://forum.proxmox.com/threads/new-feature-on-pve-console-differential-backup-for-qemu-vms.19098/
    if ($phase eq 'backup-end') {

        # Default archive type - get extension from $target.
	# Match a dot, followed by any number of non-dots until the
	# end of the line.
	my ($extension) = $target =~ /(\.[^.]+)$/;

	# Only create delta for NON COMPRESSED backups. For any compressed backups, fallback to default behavior
	if ($extension eq '.vma') {

	        print "Postprocessing Job: doing delta differential backup.\n";

	        # 0 and 7 = Sunday; 1 = Monday etc.
	        my $full_backup_day = 6; 

	        # Maximum number of groups (weeks) to keep
	        my $max = 5;

	        if ($vmtype eq 'qemu') { $extension = '.vma'; }
	        system ("
		  #comandos sh
	          if [ `date +%u` -eq $full_backup_day ]; then

		    echo Generating FULL backup;
	            touch $dumpdir/0-$vmtype-$vmid-dummy.group && rename 's/group(\\d+)/sprintf \"group%d\", \$1+1/e' $dumpdir/*-$vmtype-$vmid-*.group* && mv $target $dumpdir/`basename $target | sed \"s/$extension/\.group0.full$extension/\"` && find $dumpdir -name '*-$vmtype-$vmid-*.group$max.*' -delete;

		    #gerar um arquivo de flag para o script bkpupload.sh saber que precisa syncar os novos nomes na cloud
		    #touch $dumpdir/`date +%Y_%m_%d`.group0.rename.flag;

	          else

		    echo Generating DIFFERENTIAL backup;
	            if ls $dumpdir/*-$vmtype-$vmid-*.group0.full$extension; then

	#              screen -S delta-$vmid -d -m xdelta3 -S lzma -q -e -s `ls -1t $dumpdir/*-$vmtype-$vmid-*.group0.full.$extension | head -1` $target $dumpdir/`basename $target | cut -d'.' -f1`.group0.xdelta.$extension 
     
		         if xdelta3 -S lzma -e -v -s `ls -1t $dumpdir/*-$vmtype-$vmid-*.group0.full$extension | head -1` $target $dumpdir/`basename $target | cut -d'.' -f1`.group0.xdelta$extension; then
			      echo Success! Finished DIFFERENTIAL backup $dumpdir/`basename $target | cut -d'.' -f1`.group0.xdelta$extension
			      touch $dumpdir/`basename $target | cut -d'.' -f1`.group0.xdelta$extension.flag
			      rm $target
		      	 else
			      echo Error running Xdelta3: $?

			 fi;	

	            else
		      
	              mv $target $dumpdir/`basename $target | sed \"s/$extension/\.group0.full$extension/\"`;

	            fi;

	          fi

	                ") == 0 ||
	                die "Differential backup failed. You can try to run bash script manually";
	}
    }

    # example: copy resulting log file to another host using scp
    if ($phase eq 'log-end') {
        #system ("scp $logfile backup-host:/backup-dir") == 0 ||
        #    die "copy log file to backup-host failed";
    }

} else {

    die "got unknown phase '$phase'";

}

exit (0);
