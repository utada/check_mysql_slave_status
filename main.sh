#!/bin/bash

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
SlaveReplStatus=`${PWD}/check_mysql_slavestatus.sh -H ${host} -P ${port} -u${user} -p${password}`

if [ "${SlaveReplStatus:0:8}" = "CRITICAL" ]; then
  echo ${SlaveReplStatus}
  echo shutdown
  ShutdownResult=`mysqladmin -h ${host} -P ${port} -u ${user} --password=${password} -v shutdown`
  echo ${ShutdownResult}
  exit 1;
else
  echo ${SlaveReplStatus}
fi


