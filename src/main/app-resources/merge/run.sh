#!/bin/bash
# Project: ${project.name}
# Author: $Author: fbrito $ (Terradue Srl)
# Last update: ${doc.timestamp}:
# Element: ${project.name}
# Context: ${project.artifactId}
# Version: ${project.version} (${implementation.build})
# Description: ${project.description}
#
# This document is the property of Terradue and contains information directly
# resulting from knowledge and experience of Terradue.
# Any changes to this code is forbidden without written consent from Terradue Srl
#
# Contact: info@terradue.com
# 2012-02-10 - NEST in jobConfig upgraded to version 4B-1.1
# source the ciop functions (e.g. ciop-log)

source ${ciop_job_include}

# define the exit codes
SUCCESS=0
ERR_NOINPUT=1
ERR_NODEM=2
ERR_NOMASTER=5
ERR_NOMASTERWKT=8
ERR_NOMASTERFILE=10
ERR_NOCEOS=15
ERR_NOSLAVEWKT=20
ERR_NOSLAVEFILE=25

# add a trap to exit gracefully
function cleanExit ()
{
	local retval=$?
	local msg=""

	case "$retval" in
		$SUCCESS) msg="Processing successfully concluded";;
		$ERR_NOMASTER) msg="Master reference not provided";;
		$ERR_NOMASTERWKT) msg="Master WKT not retrieved";;
		$ERR_NOMASTERFILE) msg="Master not retrieved to local node";;
		$ERR_NODEM) msg="DEM not retrieved";;
		$ERR_NOCEOS) msg="CEOS product not retrieved";;
		$ERR_NOSLAVEFILE) msg="Slave not retrieved to local node";;
		*) msg="Unknown error";;
	esac

	[ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
	exit $retval
}
trap cleanExit EXIT

TMPDIR=/tmp/`uuidgen`
mkdir -p ${TMPDIR}


demfile=$( ciop-browseresults -r ${CIOP_WF_RUN_ID} -j node_dem | tr -d '\n\r' )
ciop-log "INFO" "retrieving input from node_dem [${demfile}]"

for input in `ciop-browseresults -r ${CIOP_WF_RUN_ID} -j node_aux`
do 
	#we add the content of the file and the dem location
	basefile=`basename $input`
	[ ${basefile:0:8} == "joborder" ] && {
		ciop-log "INFO" "using input from node_aux [${basefile}]"
		hadoop dfs -cat $input > $TMPDIR/${basefile}
		echo "dem=${demfile}" >> $TMPDIR/${basefile}
	}
	#let's publish the joborder file
	[ -e "$TMPDIR/${basefile}" ] && ciop-publish $TMPDIR/${basefile}
done

#clean up and finish
rm -rf $TMPDIR
exit $SUCCESS
