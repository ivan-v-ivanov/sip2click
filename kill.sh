#!/bin/bash

script_folder=$(dirname `readlink -f "$0"`)

while true
do
	sip2click_pid=`sudo ps aux | grep "sip2click.sh" | grep -v grep | awk '{print $2}' | head -1` 

	if [[ -n $sip2click_pid ]]; then
		sudo kill -9 $sip2click_pid
		echo "SUCCESS: sip2click (PID $sip2click_pid) was killed"
	
	else
		break
	fi	
done

rm -f $script_folder/.tcpdump.data
rm -f $script_folder/.tcpdump.data.tmp
rm -f $script_folder/.log.tmp
