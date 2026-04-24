#/* GPL-2.0 WITH Linux-syscall-note OR Apache 2.0 */
#/* Copyright (c) 2024 Fuzhou Rockchip Electronics Co., Ltd */
#!/bin/sh
output=$2/simple/output
log=$2/simple/log
report=$2/simple/report
lastnotecmd=''
lasttestcmd=''
rm -rf $output
rm -rf $log
rm -rf $report
rm -rf /tmp/simple
mkdir -p $output
mkdir -p $log
mkdir -p $report

if [ "$2" != "/tmp" ]; then
ln -s $2/simple /tmp/simple
fi

while read line
do

if [ "$line" == "" ]; then
	continue
fi

notecmd=$(echo "$line" | sed -n '/^\#/p')
if [ "$notecmd" != "" ]; then
	echo ${line}
	lastnotecmd=$(echo "$notecmd" | sed -n 's/--.*$/\1/p')
	lastnotecmd=$(echo "$lastnotecmd" | sed -n 's/^.\{2\}/\1/p')
	continue
fi

back=$(echo "$line" | sed -n '/&/p')
testcmd=$(echo "$line" | sed -n '/^simple/p')

#check md5sum
md5data=$(echo "$line" | sed -n 's/check.*$/\1/p')
md5cmd=$(echo "$line" | sed -n 's/^.*check/\1/p')

#set log level
logcmd=$(echo "$line" | sed -n 's/^.*log/\1/p')
if [ "$logcmd" != "" ]; then
	echo $logcmd > /tmp/rt_log_level
	continue
fi
#remove unexport char
log_name=$(echo "$line" | sed 's/ /_/g')
log_name=$(echo "$log_name" | sed 's/\./_/g')
log_name=$(echo "$log_name" | sed 's/\//_/g')

#check background run
if [ "$back" != "" ]; then
	cmd=$(echo "$line" | sed 's/&//g')
	log_name=$(echo "$log_name" | sed 's/&//g')
else
	cmd=$line
fi

#check testcmd cmd
if [ "$testcmd" != "" ]; then
    echo "????? ${line} start test! ?????"
	log_err_name=$log/"$lastnotecmd"_$log_name".err"
	log_name=$log/"$lastnotecmd"_$log_name".log"
	lasttestcmd=$(echo "$lastnotecmd"_"$cmd" | sed 's/ /_/g')
	lasttestcmd=$(echo "$lasttestcmd" | sed 's/\./_/g')
	lasttestcmd=$(echo "$lasttestcmd" | sed 's/\//_/g')
	echo "" > $log_err_name
else
	if [ "$md5cmd" != "" ]; then
		cmd=$md5cmd
		log_name=$output/$lasttestcmd".md5"
	else
		log_name=/dev/null
	fi
fi

#run cmd
if [ "$back" != "" ]; then
	$cmd &> $log_name&
else
	$cmd &> $log_name
fi

#check result
if [ $? -eq 0 ]; then
	#copy result
	if [ "$md5cmd" != "" ]; then
		md5file=$(sed -n 's/^.* /\1/p' $log_name)
		cp $md5file $output/$lasttestcmd".bin"
	elif [ "$testcmd" != "" ]; then
		rm $log_err_name
		echo "^^^^^ ${line} success! ^^^^"
	fi
	#md5sum check
	if [ "$md5data" != "" ]; then
		md5newdata=$(sed -n 's/ .*$/\1/p' $log_name)
		if [ "$md5newdata" != "$md5data" ]; then
			echo "$md5file md5 check fail"
			exit
		fi
	fi
else
	echo "xxxxx ${line} failed! xxxxx"
	echo $log_err_name
	exit 1
fi
done < $1
echo "test ok"
