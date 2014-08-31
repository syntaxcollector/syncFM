#!/bin/bash

# A simple script to sync filemaker databases from crosstown to yaletown
# BONUS FUNCTION: monitors remote filemaker server for TCP port connection
# SUPER BONUS FOR THE WIN: starts local file maker server when remote is offline
# Written by: Jordan Eunson jordan@copiousit.com

srcHst="yaletown"
srcDir="/Library/FileMaker\ Server/Data/Backups/"
dstDir='/Library/FileMaker\ Server/Data/Backups/'
telnet=$(which telnet)
adminEmail=( systems@copiouscom.com )
sendEmail=/usr/local/bin/sendEmail

startFM() {
/usr/bin/fmsadmin start server
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
  	for j in "${adminEmail[@]}"; {
 	$sendEmail -f "yaletown@van.adventvancouver.com" -t $j -u Cannot connect to port 5003 on $srcHst -s smtp.gmail.com:587 -xu systems@copiouscom.com -xp "" -m "FileMaker Port check failed, started FileMaker Server locally"
}
	logger -t FileMakerSync -p local0.emerg "FileMaker Port check failed"
	startFM
 	exit 0
   fi
fi
done


# Go grab the remote file maker backups and bring them all over to our backup folder locally

rsync -av --delete $srcHst:"$srcDir" /Library/FileMaker\ Server/Data/Backups/ | logger -t FileMakerSync || logger -t FileMakerSync -p local3.error 
rm -rf /Library/FileMaker\ Server/Data/Databases
cp -rp /Library/FileMaker\ Server/Data/Backups/`ls -1tr /Library/FileMaker\ Server/Data/Backups/ | tail -n 1`/Databases /Library/FileMaker\ Server/Data/Databases
