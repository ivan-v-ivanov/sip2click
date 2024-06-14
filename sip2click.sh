#!/bin/bash

### CLICKHOUSE DB CONNECTION CREDITIALS
click_db_usr=""
click_db_passwd=""
click_db_table=""
click_db_url=""
clickhouse_url=$click_db_url"database=$click_db_usr?user=$click_db_usr&password=$click_db_passwd"

### TCPDUMP GREP VARIABLES
#server_name (command: uname -n | awk -F '-' '{print $1}' or variables: "gcc", etc) - server for incoming calls 
#request_type (variables: "options" or "invite") - type of calls
server_name=`uname -n | awk -F '-' '{print $1}'`
request_type="invite"

### TIMESTEP TO STORE DATA IN DB
timestep="60"

### PATHS FOR PROJECT DIRECTORY AND PROJECT FILES
script_folder=$(dirname `readlink -f "$0"`)
logfolder="$script_folder/logfiles/"
templogfile="$script_folder/.log.tmp"
dumpdatafile="$script_folder/.tcpdump.data"
callsparser="$script_folder/callsparser.py"

### LOGGING FUNCTION
#READ .log.temp AND WRITE IT TO *.log.error
logging() {
        if [[ -n `cat $templogfile` ]]; then
                echo "`date "+%Y/%m/%d %H:%M:%S"` - `cat $templogfile`" >> $logfolder/$1
                echo "`tail -200000 $logfolder/$1`" > $logfolder/$1

		rm -f $templogfile
        fi
}

### CREATE DIRECTORY FOR LOGFILES
mkdir -p $logfolder

### CHECK THE CLICKHOUSE CONNECTION AND EXISTANCE OF TABLE
checking_output=`echo "SELECT table_name FROM information_schema.tables WHERE table_name LIKE '$click_db_table'" | curl -sS "$clickhouse_url" -d @- 2> $templogfile`
logging clickinsert.log.error

if [[ "$click_db_table" != "$checking_output" ]]; then
	echo "ERROR: wrong connection/authentication with ${click_db_url}database=${click_db_usr}?user=...&password..."
	exit 0
fi
if [[ -z $checking_output ]]; then
	echo "ERROR: table '$click_db_table' not exists"
	exit 0
fi

sudo cd $script_folder

while true
do
	sudo timeout $timestep tcpdump -i any -s 0 -A port 5060 -tttt 2> $templogfile > ${dumpdatafile}.tmp 
	logging tcpdump.log.error

	cat ${dumpdatafile}.tmp | grep -Ei "(cseq).*($request_type)" -B 14 | grep -E "> ($server_name).*\[\.\]" -A 13 | grep -e "SIP/2.0 [2,4,5].." -A 4 -B 10 > $dumpdatafile
	sudo rm -f ${dumpdatafile}.tmp

	parser_output=`sudo python3 $callsparser $dumpdatafile $server_name $timestep 2> $templogfile`
	logging callsparser.log.error
	
	if [[ -n $parser_output ]]; then
		IFS=? read -r datetime server_inputs response_codes <<< $parser_output
		echo "INSERT INTO justaistat.$click_db_table (*) VALUES (toDateTimeOrNull('$datetime'), '$server_inputs', '$response_codes')" | curl -sS "$clickhouse_url" -d @- 2> $templogfile
		logging clickinsert.log.error
	fi
	sudo rm -f $dumpdatafile
	sudo rm -f $templogfile

done

exit 0
