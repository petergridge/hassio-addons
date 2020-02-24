# hassio-addons

## About

Hass.io allows anyone to create add-on repositories to share their add-ons for
Hass.io easily. This repository is one of those repositories.


## Installation

Adding this add-ons repository to your Hass.io Home Assistant instance is
pretty easy. Follow https://home-assistant.io/hassio/installing_third_party_addons/ on the
website of Home Assistant, and use the following URL:

```txt
https://github.com/petergridge/hassio-addons/
```

## Add-ons provided by this repository

### [FTP Cycle]

## Acknowlegment
Thanks to https://github.com/leinich for providing the basis of this addon

This simple addon will create a password protected ZIP Archive of the configuration stored under /config (exclucing the Database).
The Archive will be temporarily stored under /backup as daily, weekly or monthly *.zip

The archive is uploaded to the specified FTP Server.

Each week a weekly zip will be created and the daily file removed, each month the weekly and daily zip file will be removed.

Please note that using a FTP Protocol is not secure as the ftp password will be seing in clear text.

## CONFIGURATION VARIABLES

### ftpprotocol
*(string)(Required)* ftp
#### ftpserver
*(string)(Required)* The ip address of the FTP server
#### ftpport
*(template)(Required)* For FTP this is typically 21
#### ftpbackupfolder
*(string)(Required)* The directory that will contain the zip files on the FTP server
#### ftpusername 
*(string)(Required)* THe FTP server user
#### ftppassword
*(string)(Required)* The FTP server password
#### addcurlflags
*(string)(optional)* -sS provides silent operation
#### zippassword
*(string)(Optional)* The password required to access the zip archive
#### keepmonths 
*(Int)(Required)* The number of backup cycles to keep
#### weeklyday
*(Int)(Required)* The day to consolidate the archives a number between 1 (Monday) and 7 (Sunday)

## Sensors

### sensor.addon_backup
#### friendly name: Backup
#### icon: mdi:folder-zip-outline

## Automation

To run this regularly use the following automation.

To determine the addon go to the addon in the Supervisor page and copy the name from the end of the URL.

```yaml
automation:
    - id: backup
      alias: backup
      trigger:
        platform: time
        at: 05:00:00
      action:
      - service: hassio.addon_start
        data:
          #get this from the url of the supervisor page for this addon
          addon: local_ftpbackup
```
