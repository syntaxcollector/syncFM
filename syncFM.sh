#!/bin/bash

# A simple script to sync filemaker databases from crosstown to $hostname
# BONUS FUNCTION: monitors remote filemaker server for TCP port connection
# SUPER BONUS FOR THE WIN: starts local file maker server when remote is offline
# Written by: Jordan Eunson jordan@copiousit.com

srcHst="oscar"
srcDir="/Library/FileMaker\ Server/Data/Backups/"
dstDir='/Library/FileMaker\ Server/Data/Backups/'
telnet=$(which telnet)
adminEmail=( your@email.com )
sendEmail=/usr/local/bin/sendEmail
internalDomain="lan.playmgmt.com"
hostname=`hostname`
smtpServer="smtp.gmail.com"
smtpPort="587"
smtpUser=""
smtpPass=""

startFM() {
if [ `/Library/FileMaker\ Server/Database\ Server/bin/fmserverd -help | wc -l` -eq 4 ]; then
/usr/bin/fmsadmin start server
fileMaker=0	
else 
fileMaker=1
fi
return $fileMaker
}

# connect to the remote filemaker tcp port, if the connection fails three times in a row send an email blast to adminEmail array

counter=0
for (( c=1; c<=3; c++ ))
do
(
echo "quit"
) | $telnet $srcHst 5003 | grep Connected
if [ "$?" -ne "1" ]; then #Ok
  logger -t FileMakerSync -p local6.info "Port check: OK"
else #Connection failure
  counter=$(($counter + 1))
  if [ $counter -eq 3 ]; then
	startFM
	fileMaker=$?
	if [ $fileMaker -eq 0 ]; then
 		for j in "${adminEmail[@]}"; {
 		$sendEmail -f "$hostname@$internalDomain" -t $j -u ALERT: FileMaker on $srcHst DOWN -s $smtpServer:$smtpPort -xu $smtpUser -xp "$smtpPass" -m "FileMaker Port check failed, started FileMaker Server locally. I am `hostname`"
}
		logger -t FileMakerSync -p local0.emerg "FileMaker Port check failed, started server locally"
		exit 0
        else
		for j in "${adminEmail[@]}"; {
                $sendEmail -f "$hostname@$internalDomain" -t $j -u ALERT: FileMaker on $srcHst DOWN -s $smtpServer:$smtpPort -xu $smtpUser -xp "$smtpPass" -m "FileMaker Port check failed, could not start server locally, service already running. I am `hostname`"
}
                logger -t FileMakerSync -p local0.emerg "FileMaker Port check failed, could not start server locally, service already running."
 		exit 1
	fi
   fi
fi
done


# Go grab the remote file maker backups and bring them all over to our backup folder locally

rsync -av --delete $srcHst:"$srcDir" /Library/FileMaker\ Server/Data/Backups/ | logger -t FileMakerSync || logger -t FileMakerSync -p local3.error 
rm -rf /Library/FileMaker\ Server/Data/Databases
cp -rp /Library/FileMaker\ Server/Data/Backups/`ls -1tr /Library/FileMaker\ Server/Data/Backups/ | tail -n 1`/Databases /Library/FileMaker\ Server/Data/Databases
