#! /usr/bin/nsh
#
################################################################
# Fred Breton, BMC Software - February 2014
################################################################
#
# Description: Add an entry in hosts file what ever is the OS or
#			DNS.
#
################################################################
#
# Parameters:
#	$1: Type of resolution
#	$2: ipadresse
#	$3: hostname
#
################################################################
#
# Revision: 1
#
################################################################

if [ $# -ne 3 ]
  then
	echo "
	Usage:
		UpdateHostFile.nsh resolution_type IP hostname
	Where:
		resolution_type	- Type of IP resolution, value can be File or DNS
		IP				- IP address
		hostname		- Name that have to be resolve with the IP
		"
	exit 1
  fi
RESTYPE=$1
IP=$2
HOSTNAME=$3
TMPFILE="hosttmp$(date +%d%H%M%S)"

OS=$(uname -s)
if [ $OS = "WindowsNT" ]
  then
	hostfile="/${${${$(nexec -e cmd /c echo %SystemRoot%)/:\\/\\}/\\//}%?}/System32/drivers/etc/hosts"  
  else
	hostfile="/etc/hosts"
fi

if [ $RESTYPE=="File" ]
  then
	grep -v $IP $hostfile >$TMPFILE
	echo "$IP\t$HOSTNAME" >>$TMPFILE
	mv -f $TMPFILE $hostfile
  else
	echo "No code for DNS registration"
	exit 1
  fi

