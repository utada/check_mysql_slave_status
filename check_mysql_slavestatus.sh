#!/bin/bash
#########################################################################
# Script:	check_mysql_slavestatus.sh				#
# Author:	Claudio Kuenzler www.claudiokuenzler.com		#
# Purpose:	Monitor MySQL Replication status with Nagios		#
# Description:	Connects to given MySQL hosts and checks for running 	#
#		SLAVE state and delivers additional info		#
# Original:	This script is a modified version of 			#
#		check mysql slave sql running written by dhirajt	#
# Thanks to:	Victor Balada Diaz for his ideas added on 20080930	#
#		Soren Klintrup for stuff added on 20081015		#
#		Marc Feret for Slave_IO_Running check 20111227		#
#		Peter Lecki for his mods added on 20120803		#
# History:	2008041700 Original Script modified			#
#		2008041701 Added additional info if status OK		#
#		2008041702 Added usage of script with params -H -u -p	#
#		2008041703 Added bindir variable for multiple platforms	#
#		2008041704 Added help because mankind needs help	#
#		2008093000 Using /bin/sh instead of /bin/bash		#
#		2008093001 Added port for MySQL server			#
#		2008093002 Added mysqldir if mysql binary is elsewhere	#
#		2008101501 Changed bindir/mysqldir to use PATH		#
#		2008101501 Use $() instead of `` to avoid forks		#
#		2008101501 Use ${} for variables to prevent problems	#
#		2008101501 Check if required commands exist		#
#		2008101501 Check if mysql connection works		#
#		2008101501 Exit with unknown status at script end	#
#		2008101501 Also display help if no option is given	#
#		2008101501 Add warning/critical check to delay		#
#		2011062200 Add perfdata					#
#		2011122700 Checking Slave_IO_Running			#
#		2012080300 Changed to use only one mysql query		#
#		2012080301 Added warn and crit delay as optional args	#
#		2012080302 Added standard -h option for syntax help	#
#		2012080303 Added check for mandatory options passed in	#
#		2012080304 Added error output from mysql		#
#		2012080305 Changed from 'cut' to 'awk' (eliminate ws)	#
#########################################################################
# Usage: ./check_mysql_slavestatus.sh -H dbhost -P port -u dbuser -p dbpass
#########################################################################
help="\ncheck_mysql_slavestatus.sh (c) 2008-2012 GNU GPLv2 licence
Usage: check_mysql_slavestatus.sh -H host -P port -u username -p password [-w warn_delay] [-c crit_delay]\n
Options:\n-H Hostname or IP of slave server\n-P Port of slave server\n-u Username of DB-user\n-p Password of DB-user\n-w Delay in seconds for Warning status (optional, default ${warn_delay})\n-c Delay in seconds for Critical status (optional, default ${crit_delay})\n
Attention: The DB-user you type in must have CLIENT REPLICATION rights on the DB-server.\n"

STATE_OK=0		# define the exit code if status is OK
STATE_WARNING=1		# define the exit code if status is Warning (not really used)
STATE_CRITICAL=2	# define the exit code if status is Critical
STATE_UNKNOWN=3		# define the exit code if status is Unknown
PATH=/usr/local/bin:/usr/bin:/bin # Set path
crit="No"		# what is the answer of MySQL Slave_SQL_Running for a Critical status?
ok="Yes"		# what is the answer of MySQL Slave_SQL_Running for an OK status?
warn_delay=10 # warning at this delay
crit_delay=60 # critical at this delay

for cmd in mysql awk grep [ 
do
 if ! `which ${cmd} &>/dev/null`
 then
  echo "UNKNOWN: This script requires the command '${cmd}' but it does not exist; please check if command exists and PATH is correct"
  exit ${STATE_UNKNOWN}
 fi
done

# Check for people who need help - aren't we all nice ;-)
#########################################################################
if [ "${1}" = "--help" -o "${#}" = "0" ]; 
	then 
	echo -e "${help}";
	exit 1;
fi

# Important given variables for the DB-Connect
#########################################################################
while getopts "H:P:u:p:w:c:h" Input;
do
	case ${Input} in
	H)	host=${OPTARG};;
	P)	port=${OPTARG};;
	u)	user=${OPTARG};;
	p)	password=${OPTARG};;
	w)      warn_delay=${OPTARG};;
	c)      crit_delay=${OPTARG};;
	h)      echo -e "${help}"; exit 1;;
	\?)	echo "Wrong option given. Please use options -H for host, -P for port, -u for user and -p for password"
		exit 1
		;;
	esac
done

# Connect to the DB server and check for informations
#########################################################################
# Check whether all required arguments were passed in
if [ -z "${host}" -o -z "${port}" -o -z "${user}" -o -z "${password}" ];then
	echo -e "${help}"
	exit ${STATE_UNKNOWN}
fi
# Connect to the DB server and store output in vars
ConnectionResult=`mysql -h ${host} -P ${port} -u ${user} --password=${password} -e 'show slave status\G' 2>&1`
if [ -z "`echo "${ConnectionResult}" |grep Slave_IO_State`" ]; then
	echo -e "CRITICAL: Unable to connect to server ${host}:${port} with username '${user}' and password '${password}'\n${ConnectionResult}"
	exit ${STATE_CRITICAL}
fi
check=`echo "${ConnectionResult}" |grep Slave_SQL_Running | awk '{print $2}'`
checkio=`echo "${ConnectionResult}" |grep Slave_IO_Running | awk '{print $2}'`
masterinfo=`echo "${ConnectionResult}" |grep  Master_Host | awk '{print $2}'`
delayinfo=`echo "${ConnectionResult}" |grep Seconds_Behind_Master | awk '{print $2}'`

# Output of different exit states
#########################################################################
if [ ${check} = "NULL" ]; then 
echo CRITICAL: Slave_SQL_Running is answering NULL
exit ${STATE_CRITICAL};
fi

if [ ${check} = ${crit} ]; then 
echo CRITICAL: ${host}:${port} Slave_SQL_Running: ${check}
exit ${STATE_CRITICAL};
fi

if [ ${checkio} = ${crit} ]; then 
echo CRITICAL: ${host} Slave IO Running: ${checkio}
exit ${STATE_CRITICAL};
fi

if [ ${check} = ${ok} ]; then
 if [ "${delayinfo}" -ge "${warn_delay}" ]
 then
  if [ "${delayinfo}" -ge "${crit_delay}" ]
  then
   echo "CRITICAL: slave is ${delayinfo} seconds behind master | delay=${delayinfo}s"
   exit ${STATE_CRITICAL}
  else
   echo "WARNING: slave is ${delayinfo} seconds behind master | delay=${delayinfo}s"
   exit ${STATE_WARNING}
  fi
 else
  echo "OK: Slave SQL running: ${check} Slave IO running: ${checkio} / master: ${masterinfo} / slave is ${delayinfo} seconds behind master | delay=${delayinfo}s"
  exit ${STATE_OK};
 fi
fi

echo "UNKNOWN: should never reach this part"
exit ${STATE_UNKNOWN}
