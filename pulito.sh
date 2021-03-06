#!/bin/bash
# pulito - 'clean' in Italian
# Script to copy s3 buckes and scan them for virus the log output
# poorly written ceh 15NOV16
# Usage pulito S3BUCKETNAME
# Dependent on clamscan, fuse, and s3fs
# https://github.com/s3fs-fuse/s3fs-fuse.git


LOG_DIR='[LOG DIRECTORY]'
MOUNT_DIR='[MOUNT LOCATION]'
DATA_DIR='[WHERE THE DATA LIVES]'
CACHE_DIR='[WHERE TO STORE DATA CACHE]'


if [ -z $1 ]; then
    echo "Usage: $0 S3BUCKETNAME"
    exit;
fi

#test for mountpoint, try to mount, bail if fail
if grep -qs "$1" /proc/mounts; then
  echo `date`  $1 "is already mounted." >> $LOG_DIR/$1 2>&1
else
  echo `date` $1 "is not mounted." >> $LOG_DIR/$1 2>&1
  /usr/bin/s3fs -o allow_other -o use_cache=$CACHE_DIR $1 $MOUNT_DIR/$1
  sleep 5
  if [ $? -eq 0 ]; then
   echo `date` "Mount success!" >> $LOG_DIR/$1 2>&1
  else
   echo `date` "Something went wrong with the mount..." >> $LOG_DIR/$1 2>&1
   exit
  fi
fi

echo `date` "starting rsync on" $1 >> $LOG_DIR/$1 2>&1
rsync -a $MOUNT_DIR/$1 $DATA_DIR >> $LOG_DIR/$1 2>>$1

echo `date` "starting clamav on" $1 >> $LOG_DIR/$1 2>&1
clamscan -i -r $MOUNT_DIR/$1 >> $LOG_DIR/$1 2>&1
