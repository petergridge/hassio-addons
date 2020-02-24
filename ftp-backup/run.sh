#!/usr/bin/env bashio
set -e

echo "[Info] Starting!"

CONFIG_PATH=/data/options.json
ftpprotocol=$(jq --raw-output ".ftpprotocol" $CONFIG_PATH)
ftpserver=$(jq --raw-output ".ftpserver" $CONFIG_PATH)
ftpport=$(jq --raw-output ".ftpport" $CONFIG_PATH)
ftpbackupfolder=$(jq --raw-output ".ftpbackupfolder" $CONFIG_PATH)
ftpusername=$(jq --raw-output ".ftpusername" $CONFIG_PATH)
ftppassword=$(jq --raw-output ".ftppassword" $CONFIG_PATH)
addcurlflags=$(jq --raw-output ".addcurlflags" $CONFIG_PATH)
zippassword=$(jq --raw-output ".zippassword" $CONFIG_PATH)
keepmonths=$(jq --raw-output ".keepmonths" $CONFIG_PATH)
weeklyday=$(jq --raw-output ".weeklyday" $CONFIG_PATH)

auth_header="Authorization: Bearer ${__BASHIO_SUPERVISOR_TOKEN}"

curlurl="http://supervisor/core/api/states/sensor.addon_backup"
response=$(curl $addcurlflags \
     -X POST $curlurl \
     -H "${auth_header}" \
     -H "Content-Type: application/json" \
     -d '{"state":"In Progress"}')

ftpurl="$ftpprotocol://$ftpserver:$ftpport/$ftpbackupfolder/"
credentials=""
if [ "${#ftppassword}" -gt "0" ]; then
	credentials="-u $ftpusername:$ftppassword"
fi

today=`date +%Y%m%d%H%M%S`
hassconfig="/config"
hassbackup="/backup"

#day of the month
DOM=`date +%d`
#day of the week, 1 is Monday
DOW=`date +%u`

echo "[Info] Creating ZIP archive"
if [ $DOM == $weeklyday ] && [ $DOM -lt 8 ]; then
  PROCESS="M"
  zipprefix="monthly_"
elif [ $DOW == $weeklyday ]; then
  PROCESS="W"
  zipprefix="weekly_"
else
  PROCESS="D"
  zipprefix="daily_"
fi
zipname="$zipprefix$today.zip"
zippath="$hassbackup/$zipname"

cd $hassconfig
zip -P $zippassword -r -q $zippath . -x ./*.db ./*.db-shm ./*.db-wal
echo "[Info] ZIP archive created"

echo "[Info] Uploading $zipname to FTP server"
curl  $addcurlflags $credentials -T $zippath $ftpurl
echo "[Info] Upload to FTP server complete"

echo "[Info] Creating working files"
cd $hassbackup
curl --list-only $addcurlflags $credentials $ftpurl >dirlist

set +e
grep daily dirlist >dailyfiles
grep weekly dirlist >weeklyfiles
grep monthly dirlist >monthlyfiles
set -e

if [ $PROCESS == "M" ] || [ $PROCESS == "W" ]; then
  while read p; do
    echo "[Info] Deleting $p from ftp server $ftpserver"
    curl $addcurlflags $ftpurl $credentials -o dirlist --quote "DELE ${ftpbackupfolder}/${p}"
  done <dailyfiles
fi

if [ $PROCESS == "M" ]; then
  while read p; do
    echo "[Info] Deleting $p from ftp server $ftpserver"
    curl $addcurlflags $ftpurl $credentials -o dirlist --quote "DELE ${ftpbackupfolder}/${p}"
  done <weeklyfiles
  #delete monthly files older than keepmonths old
  #have to use this method as HASSOS does not support all date operations
  MONTH=`date +%m`
  MONTH=${MONTH#0}
  YEAR=`date +%Y`
  ZERO="0"
  DAYTIME="28000000"
  MONTH="$((MONTH-keepmonths))"
  if [ $MONTH -lt 1 ];   then
    $MONTH=12+$MONTH
    $YEAR=$YEAR-1
  fi
  if [ $MONTH -lt 10 ]; then
      COMP=$YEAR$ZERO$MONTH$DAYTIME
  else
      COMP=$YEAR$MONTH$DAYTIME
  fi

  #extract datetime from the file name
  awk -F"[_.]" '{ print $2 }'<monthlyfiles >monthlyfiles2
  #remove blank lines
  sed -i '/^$/d' monthlyfiles2

  while read p; do
    if [ $p -lt $COMP ]; then
      zip=monthly_$p.zip
      echo "[Info] Deleting $zip from ftp server $ftpserver"
      curl $addcurlflags $ftpurl $credentials -o dirlist --quote "DELE ${ftpbackupfolder}/${zip}"
    fi
  done <monthlyfiles2
  rm monthlyfiles2

fi

echo "[Info] Deleting zip files created earlier today"
#extract datetime from the file name
awk -F"[_.]" '{ print $2 }'<dirlist >dirlist2
#remove blank lines
sed -i '/^$/d' dirlist2

while read p; do
  PDATE="$(printf '%.8s' $p)"
  DATE=`date +%Y%m%d`
  if [ $PDATE -eq $DATE ] && [ $p -ne $today ]; then
    zip=$zipprefix$p.zip
    echo "[Info] Deleting $zip from ftp server $ftpserver"
    set +e
    response=$(curl $addcurlflags $ftpurl \
         $credentials \
         --quote "DELE ${ftpbackupfolder}/${zip}")
    set -e
  fi
done <dirlist2

echo "[Info] Cleaning up workfiles"
cd $hassbackup
rm dirlist
rm dirlist2
rm weeklyfiles
rm dailyfiles
rm monthlyfiles
find $hassbackup -type f -name $zipname -exec rm {} \;
echo "[Info] Workfiles removed"

response=$(curl $addcurlflags \
     -X POST $curlurl \
     -H "${auth_header}" \
     -H "Content-Type: application/json" \
     -d '{"state":"Success"}')