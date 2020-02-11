#!/bin/bash
set -e

echo "[Info] Starting FTP Backup docker!"

CONFIG_PATH=/data/options.json
ftpprotocol=$(jq --raw-output ".ftpprotocol" $CONFIG_PATH)
ftpserver=$(jq --raw-output ".ftpserver" $CONFIG_PATH)
ftpport=$(jq --raw-output ".ftpport" $CONFIG_PATH)
ftpbackupfolder=$(jq --raw-output ".ftpbackupfolder" $CONFIG_PATH)
ftpusername=$(jq --raw-output ".ftpusername" $CONFIG_PATH)
ftppassword=$(jq --raw-output ".ftppassword" $CONFIG_PATH)
addftpflags=$(jq --raw-output ".addftpflags" $CONFIG_PATH)
zippassword=$(jq --raw-output ".zippassword" $CONFIG_PATH)
keepdays=$(jq --raw-output ".keepdays" $CONFIG_PATH)

ftpurl="$ftpprotocol://$ftpserver:$ftpport/$ftpbackupfolder/"
credentials=""
if [ "${#ftppassword}" -gt "0" ]; then
	credentials="-u $ftpusername:$ftppassword"
fi
	
today=`date +%Y%m%d%H%M%S`
hassconfig="/config"
hassbackup="/backup"
zipfile="homeassistant_backup_$today.zip"
zippath="$hassbackup/$zipfile"

echo "[Info] Starting backup creating $zippath"
cd $hassconfig
zip -P $zippassword -r $zippath . -x ./*.db ./*.db-shm ./*.db-wal
echo "[Info] Finished archiving configuration"

echo "[Info] trying to upload $zippath to $ftpurl"
curl $addftpflags $credentials -T $zippath $ftpurl
echo "[Info] Finished ftp backup"

echo "[Info] removing existing zip files from $hassbackup"
cd $hassbackup
find  -mtime -10 -type f -name '*.zip' -exec ls \;
find  -mtime +$keepdays -type f -name '*.zip' -delete
echo "[info] zip files removed"

echo "[Info] remove older files from $ftpurl"
ndays=$keepdays

# work out our cutoff date  RMDATE=$(date --iso -d '6 days ago')
#MM=`date --iso '$ndays days ago'
#DD=`date --date="$ndays days ago" +%d`
#TT=`date --date="$ndays days ago" +%s`

echo "removing files older than $MM $DD"

# get directory listing from remote source
echo "
cd $ftpbackupfolder
ls -l
"|$ftpsite >dirlist

# skip first three and last line, ftp command echo
listing="`tail -n+4 dirlist|head -n-1`"

lista=( $listing )

# loop over our files
#for ((FNO=0; FNO<${#lista[@]}; FNO+=9));do
  # month (element 5), day (element 6) and filename (element 8)
  # echo Date ${lista[`expr $FNO+5`]} ${lista[`expr $FNO+6`]}          File: ${lista[`expr $FNO+8`]}

#  fdate="${lista[`expr $FNO+5`]} ${lista[`expr $FNO+6`]} ${lista[`expr $FNO+7`]}"
#  sdate=`date --date="$fdate" +%s`
  # check the date stamp
#  if [ $sdate -lt $TT ]
#  then
      # Remove this file
      echo "$MM $DD: Removing  ${lista[`expr $FNO+5`]} /  ${lista[`expr $FNO+6`]} / ${lista[`expr $FNO+8`]}"
#      $ftpsite <<EOMYF2
#      cd $putdir
#      delete ${lista[`expr $FNO+8`]}
#      quit
#EOMYF2

#  fi
