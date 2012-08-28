#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while getopts "H:P:u:p:" Input; do
	case ${Input} in
	H)	host=${OPTARG};;
	P)	port=${OPTARG};;
	u)	user=${OPTARG};;
	p)	password=${OPTARG};;
	\?)	echo "Wrong option given. Please use options -H for host, -P for port, -u for user and -p for password"
		exit 1
		;;
  esac
done

# ${PWD##*/}
err_cnt=0
while :
do 
    SlaveReplStatus=`${DIR}/check_mysql_slavestatus.sh -H ${host} -P ${port} -u${user} -p${password}`
    
    if [ "${SlaveReplStatus:0:8}" = "CRITICAL" ]; then
        echo ${err_cnt}
        echo ${SlaveReplStatus}
        err_cnt=$((err_cnt+1))
    else
        echo ${SlaveReplStatus}
    fi

    if [[ $err_cnt > 5 ]]; then
        echo shutdown
        ShutdownResult=`mysqladmin -h ${host} -P ${port} -u ${user} --password=${password} -v shutdown`
        echo ${ShutdownResult}
        exit 1;
    fi

    sleep 5

done

