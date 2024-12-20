#!/sbin/sh
###########################################################################
#
# get all qseecomd dependencies dynamically from the current installed OS
#
# Copyright 2017-2024 steadfasterX <steadfasterX #AT# gmail -DOT- com>
#
###########################################################################

LOG=/tmp/recovery.log
TAG=PREPDEC

F_LOG(){
   MSG="$1"
   echo -e "I:$TAG: $(date +%F_%T) - $MSG" >> $LOG
}
F_ELOG(){
   MSG="$1"
   echo -e "E:$TAG: $(date +%F_%T) - $MSG" >> $LOG
}
F_LOG "Started $0"
F_LOG "cryptprep.state: $(getprop cryptprep.state)"
setprop crypto.ready 0  >> $LOG 2>&1

relink()
{
	fname=$(basename "$1")
	target="/sbin/$fname"
	sed 's|/system/bin/linker64|///////sbin/linker64|' "$1" > "$target"
	chmod 755 $target
        F_LOG "relinking $1->$target finished"
}

# the dev path can be different so we need to identify it
syspathsoc="/dev/block/platform/soc.0/f9824900.sdhci/by-name/system"
syspathnosoc="/dev/block/platform/f9824900.sdhci/by-name/system"
syspath=undefined
while [ ! -e "$syspath" ];do
    [ -e "$syspathnosoc" ] && syspath="$syspathnosoc"
    [ -e "$syspathsoc" ] && syspath="$syspathsoc"
    F_LOG "syspath: $syspath"
    [ "$syspath" == "undefined" ] && F_LOG "sleeping a bit as syspath is not there yet.." && sleep 1
done

# directories
F_LOG "Preparing directories:"

cdirs="/vendor/lib64/hw /vendor/lib /vendor/bin /s"

for cd in $cdirs;do
    mkdir -p $cd >> $LOG 2>&1
done

# mount temp system
mount -t ext4 -o ro "$syspath" /s  >> $LOG 2>&1 || F_ELOG "mounting /s to $syspath failed"

# this relinks (linker64) AND copies qseecomd to /sbin
#if [ -f /s/vendor/bin/qseecomd ];then
#    relink /s/vendor/bin/qseecomd  >> $LOG 2>&1
#    [ $? -ne 0 ] && F_ELOG "relinking qseecomd failed (vendor)"
#else
#    relink /s/bin/qseecomd >> $LOG 2>&1 || F_ELOG "relinking qseecomd failed"
#    [ $? -ne 0 ] && F_ELOG "relinking qseecomd failed (system)"
#fi

F_LOG "preparing libraries..."

qcom_deps="
            /vendor/bin/qseecomd
            /vendor/lib64/libdiag.so
            /vendor/lib64/libdrmfs.so
            /vendor/lib64/libdrmtime.so
            /vendor/lib64/libQSEEComAPI.so
            /vendor/lib64/librpmb.so
            /vendor/lib64/libssd.so
            /vendor/lib64/libdrmtime.so
            /vendor/lib64/libtime_genoff.so
            /vendor/lib64/hw/keystore.msm8992.so
            /vendor/lib64/hw/gatekeeper.msm8992.so
            /vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so
            /vendor/lib64/hw/android.hardware.keymaster@3.0-impl.so
            /vendor/lib64/libmdtp.so
"

# copy the qseecomd & dependencies to ramdisk
for qf in $qcom_deps;do
    cp -v /s${qf} $qf >> $LOG 2>&1 
done
# keystore might be in system/lib64 instead of vendor
cp -v /s/lib64/hw/keystore.msm8992.so /vendor/lib64/hw/ >> $LOG 2>&1
# libsoftkeymaster must be in /sbin
cp -v /s/vendor/lib64/libsoftkeymaster.so /sbin/ >> $LOG 2>&1

F_LOG "preparing libraries finished"

umount /s >> $LOG 2>&1 || F_ELOG "unmounting /s failed"

# inform init to start qseecomd
setprop cryptprep.state ready >> $LOG 2>&1 
F_LOG "cryptprep.state: $(getprop cryptprep.state)"

F_LOG "current mounts: \n$(mount)"

F_LOG "$0 ended"
exit 0
