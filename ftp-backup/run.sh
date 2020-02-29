#!/usr/bin/env bashio
set -e

bashio::log.info "Starting!"

post_data()
{

  local data='{"state": "'"$1"'", "attributes": { "icon" : "mdi:folder-zip-outline", "friendly_name" : "Backup","File":"'"$2"'" } }'

  local auth_header="Authorization: Bearer ${__BASHIO_SUPERVISOR_TOKEN}"
  local curlurl="http://supervisor/core/api/states/sensor.addon_backup"
  local response=$(curl $addcurlflags \
       -X POST $curlurl \
       -H "${auth_header}" \
       -H "Content-Type: application/json" \
       -d "$data" )

  echo $data
}

target_date()
{
  #Parameter keep_months
  #have to use this method as BUSYBOX does not support GNU date operations
  local COMP  
  local MONTH=$(date +%m)
  MONTH=${MONTH#0}
  MONTH="$((MONTH-$1))"
  local YEAR=$(date +%Y)
  local ZERO="0"
  if [ $MONTH -lt 1 ]; then
    MONTH="$((MONTH+12))"
    YEAR="$((YEAR-1))"
  fi
  if [ $MONTH -lt 10 ]; then
      COMP=$YEAR$ZERO$MONTH
  else
      COMP=$YEAR$MONTH
  fi

  echo $COMP
}

ftpprotocol=$(bashio::config 'ftp_protocol')
ftpserver=$(bashio::config 'ftp_server')
ftpport=$(bashio::config 'ftp_port')
ftpbackupfolder=$(bashio::config 'ftp_backup_folder')
ftpusername=$(bashio::config 'ftp_username')
ftppassword=$(bashio::config 'ftp_password')
addcurlflags=$(bashio::config 'add_curl_flags')
zippassword=$(bashio::config 'zip_password')
keepmonths=$(bashio::config 'keep_months')
weeklyday=$(bashio::config 'weekly_day')
loglevel=$(bashio::config 'log_level')

if [ $loglevel != null ]; then
  bashio::log.level $loglevel
fi

response=$(post_data "In Progress" "")

ftpurl="$ftpprotocol://$ftpserver:$ftpport/$ftpbackupfolder/"
credentials=""
if [ "${#ftppassword}" -gt "0" ]; then
	credentials="-u $ftpusername:$ftppassword"
fi

lastfile=$(date +%Y%m%d%H%M%S)
hassconfig="/config"
hassbackup="/backup"

#day of the month
DOM=$(date +%d)
#day of the week, 1 is Monday
DOW=$(date +%u)

bashio::log.debug "DOW $DOW"
bashio::log.debug "DOM $DOM"

if [ $DOW == $weeklyday ] && [ $DOM -lt 8 ]; then
  PROCESS="M"
  zipprefix="monthly_"
elif [ $DOW == $weeklyday ]; then
  PROCESS="W"
  zipprefix="weekly_"
else
  PROCESS="D"
  zipprefix="daily_"
fi
zipname="$zipprefix$lastfile.zip"
zippath="$hassbackup/$zipname"

bashio::log.debug "process $PROCESS"
bashio::log.debug "weeklyday $weeklyday"
bashio::log.debug "zipname $zipname"
bashio::log.debug "zippath $zippath"

bashio::log.info "Creating ZIP archive $zipname"

cd $hassconfig
zip -P $zippassword -r -q $zippath . -x ./*.db ./*.db-shm ./*.db-wal
bashio::log.info "ZIP archive created"

credentials=""
if [ "${#ftppassword}" -gt "0" ]; then
  credentials="-u $ftpusername:$ftppassword"
fi

bashio::log.info "Uploading $zipname to FTP server"
curl  $addcurlflags $credentials -T $zippath $ftpurl
bashio::log.info "Upload to FTP server complete"

bashio::log.info "Cleaning up files"
cd $hassbackup
curl --list-only $addcurlflags $credentials $ftpurl >dirlist

while read p; do
  delete=""

  if [ $PROCESS == "M" ] || [ $PROCESS == "W" ]; then
    if [ ${p:0:5} == "daily" ]; then
      #delete all dailys
      bashio::log.debug "delete daily - ${p:0:5}"
      delete=$p
    fi
  fi
  if [ $PROCESS == "M" ]; then
    if [ ${p:0:6} == "weekly" ]; then
      #creating a monthly delete all weeklys
      bashio::log.debug "delete weekly - ${p:0:6}"
      delete=$p
    fi
    if [ ${p:0:7} == "monthly" ]; then
      #more than keep_months old
      bashio::log.debug "delete monthly - ${p:0:7}"
      s=${p:(-18):6}
      t=$(target_date $keepmonths)
      bashio::log.debug "s - $s"
      bashio::log.debug "t - $t"
      if (( $s < $t )); then
        bashio::log.debug "file is older than keep_months"
        delete=$p
      fi
    fi
  fi

  bashio::log.debug "Process $PROCESS - ${p:(-18):6} - $(target_date $keepmonths)"
  bashio::log.debug "p:(-18):8 - ${p:(-18):8}"
  bashio::log.debug "date +%Y%m%d - $(date +%Y%m%d)"
  bashio::log.debug "p:(-18):14 - ${p:(-18):14}"
  bashio::log.debug "lastfile - $lastfile"
  bashio::log.debug "loglevel - $loglevel"

  if [ $loglevel == "debug" ] && [ ${p:(-18):8} -eq $(date +%Y%m%d) ] && [ ${p:(-18):14} -ne $lastfile ]; then
    #delete older files created today
    bashio::log.debug "delete older files created today"
    delete=$p
  fi
  if [ "${#delete}" -gt "0" ]; then
    bashio::log.info "Deleting $delete from ftp server $ftpserver"
    response=$(curl $addcurlflags $credentials $ftpurl --quote "DELE ${ftpbackupfolder}/${delete}")
  fi
done <dirlist

bashio::log.info "Removing workfiles"
cd $hassbackup
rm dirlist
find $hassbackup -type f -name $zipname -exec rm {} \;
bashio::log.info "Workfiles removed"

response=$(post_data "Success" $zipname)
bashio::log.info "Finished!"
