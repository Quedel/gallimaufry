#!/bin/bash

# Nagios compatible script to check CPU load of Netgear switches with SNMP
#
# LICENSE: GPLv3, Copyright 2018 Helmut Wenzel <hwenzel {at} gmail {dot} com>
#
# Return codes:
#	0	OK
#	1	WARNING
#	2	CRITICAL
#	3	UNKNOWN
#
# Version 1.0


# Default SNMP community
COM=public

# Default SNMP version
VERS=2c

# Default SNMP port
PORT=161

# Default warning treshold
WARNING=60

#Default critical treshold
CRITICAL=90 

# Constants
RET_OK=0
RET_WARN=1
RET_CRIT=2
RET_UNKN=3

#------
# Usage
#------

usage() {
    echo "Usage:"
    echo "	$0 -H <host> -o OID -i 5|60|300"
    echo "	  [-w warn_range] [-c crit_range] [-C community] [-v version] [-s 'any_snmp_args'] [-V] [--help]"
    echo ""
    echo "Options: "
    echo "	-h, --help		This help"
    echo "	-H, --host		Checked switch virtual IP"
    echo "	-o, --oid		Object identifier or SNMP variables of CPU load"
    echo "	-i, --interval		Average CPU load interval in seconds (5|60|300)"
    echo "	-w, --warning		Warning treshold, default=60"
    echo "	-c, --critical		Critical treshold, default=90"
    echo "	-C, --community		SNMP community, default=public"
    echo "	-v, --version		SNMP version, default=2c"
    echo "	-s, --snmp-args		Any SNMP args you d'like to add to snmpwalk command"
    echo "	-p, --port		SNMP port, default=161"
    echo "	-V, --verbose		Verbose output, mainly for debugging"
    echo ""
    exit $RET_UNKN
}

RET_CODE=$RET_OK
VERBOSE=0
WILD_ARGS=
VALUE=

OPTS=$(getopt -o hH:o:i:w:c:C:v:s:V --long help,host:,oid:,interval:,warning:,critical:,community:,version:,snmp-args:,port:,verbose -n "$0" -- "$@")
[ $? -ne 0 ] && usage
eval set -- "$OPTS"
while [ $# -gt 0 ]; do
    case $1 in
	-h|--help)	usage;		shift ;;
	-H|--host)	ADR=$2;		shift 2 ;;
	-o|--oid)	OID=$2;		shift 2 ;;
	-i|--interval)	INTERVAL="$2";	shift 2 ;;
	-w|--warning)	WARNING=$2;	shift 2 ;;
	-c|--critical)	CRITICAL=$2;	shift 2 ;;
	-C|--community)	COM=$2;		shift 2 ;;
	-v|--version)	VERS=$2;	shift 2 ;;
	-s|--snmp-args)	WILD_ARGS="$2";	shift 2 ;;
	-p|--port)	PORT=$2;	shift 2 ;;
	-V|--verbose)	VERBOSE=1;	shift ;;
	--)		shift;	break ;;
	*)		echo "Unknown argument: $1"
		        usage
	;;
    esac
done

[ -z "$ADR" ] && echo "Unspecified host." && usage
[ -z "$OID" ] && echo "Unspecified SNMP OID." && usage
[ -z "$INTERVAL" ] && echo "Unspecified interval." && usage
[ -z "$WARNING" ] && echo "Unspecified warning treshold." && usage
[ -z "$CRITICAL" ] && echo "Unspecified critical treshold." && usage
[ -z "$COM" ] && echo "Unspecified SNMP community." && usage
[ -z "$VERS" ] && echo "Unspecified SNMP version." && usage
[ -z "$PORT" ] && echo "Unspecified SNMP port." && usage

# Query CPU load
resu=`snmpwalk -Oqv -v$VERS -c$COM $ADR:$PORT $WILD_ARGS $OID 2>&1`
resu_code=$?

[ $VERBOSE -eq 1 ] && echo -e "DEBUG: SNMP Return: $resu"

# SNMP error?
if [ $resu_code -ne 0 -o -n "`echo "$resu" | grep snmpwalk:`" ]; then
    echo "UNKNOWN - SNMP error (ret code $resu_code): $resu"
    exit $RET_UNKN
fi

# grep the right value
case "$INTERVAL" in
    5)
	VALUE="$(echo $resu | cut -d'%' -f1 | rev | cut -d' ' -f1 | rev)"
	;;
    60)
	VALUE="$(echo $resu | cut -d'%' -f2 | rev | cut -d' ' -f1 | rev)"
	;;
    300)
	VALUE="$(echo $resu | cut -d'%' -f3 | rev | cut -d' ' -f1 | rev)"
	;;
    *)
	echo "Wrong value for interval." && usage
esac

VALUEINT=${VALUE%.*}
[ $VERBOSE -eq 1 ] && echo -e "DEBUG: value to int = $VALUEINT"

if [ $WARNING -gt 0 -o $CRITICAL -gt 0 ]; then
    [ $VERBOSE -eq 1 ] && echo -e "DEBUG: warning/critical treshold is set"

    if [ $VALUEINT -gt $CRITICAL ]; then
	echo "SNMP CRITICAL - $VALUE | CPU_LOAD=$VALUE"
	RET_CODE=$RET_CRIT
    elif [ $VALUEINT -gt $WARNING ]; then
	echo "SNMP WARNING - $VALUE | CPU_LOAD=$VALUE"
	RET_CODE=$RET_WARN
    else
	echo "SNMP OK - $VALUE | CPU_LOAD=$VALUE"
    fi
else
    echo "SNMP OK - $VALUE | CPU_LOAD=$VALUE"
fi

exit $RET_CODE
