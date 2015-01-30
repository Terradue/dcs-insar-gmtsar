#!/bin/bash

# source the ciop functions (e.g. ciop-log)
source ${ciop_job_include}

export OS=`uname -p`
export GMTHOME=/usr
export NETCDFHOME=/usr
export GMTSARHOME=/usr/local/GMTSAR
export GMTSAR=$GMTSARHOME/gmtsar
export ENVIPRE=$GMTSARHOME/ENVISAT_preproc
export PATH=$GMTSAR/bin:$GMTSAR/csh:$GMTSARHOME/preproc/bin:$GMTSARHOME/ENVISAT_preproc/bin/:$GMTSARHOME/ENVISAT_preproc/csh:$PATH

# define the exit codes
SUCCESS=0
ERR_NOINPUT=1
ERR_NODEM=2
ERR_AUX=3
ERR_NOMASTER=5
ERR_NOMASTERWKT=8
ERR_NOMASTERFILE=10
ERR_NOCEOS=15
ERR_NOSLAVEWKT=20
ERR_NOSLAVEFILE=25

# add a trap to exit gracefully
function cleanExit () {
	local retval=$?
	local msg=""
	case "$retval" in
		$SUCCESS)		msg="Processing successfully concluded";;
		$ERR_NOMASTER)		msg="Master reference not provided";;
		$ERR_NOMASTERWKT)	msg="Master WKT not retrieved";;
		$ERR_NOMASTERFILE)	msg="Master not retrieved to local node";;	
		$ERR_NODEM)		msg="DEM not retrieved";;
		$ERR_AUX)		msg="Failed to retrieve auxiliary and/or orbital data";;
		$ERR_NOCEOS)		msg="CEOS product not retrieved";;
		$ERR_NOSLAVEFILE)	msg="Slave not retrieved to local node";;
		*)			msg="Unknown error";;
	esac

	[ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
	exit $retval
}
trap cleanExit EXIT

TMPDIR=/tmp/`uuidgen`

# create environment
mkdir -p $TMPDIR/runtime/raw $TMPDIR/runtime/topo $TMPDIR/runtime/log $TMPDIR/runtime/intf &> /dev/null
mkdir -p $TMPDIR/aux/ENVI/ASA_INS
mkdir -p $TMPDIR/aux/ENVI/Doris

export ORBITS=$TMPDIR/aux
#first="true"

while read input
do
	ciop-log "INFO" "retrieving $input"
	input=`ciop-copy -O $TMPDIR $input`

	#demfile=$( ciop-browseresults -r $CIOP_WF_RUN_ID -j node_dem | tr -d '\n\r' )
	demfile=`cat $input | grep "^dem=" | cut -d "=" -f 2-`
	ciop-log "INFO" "DEM is: $demfile [$CIOP_WF_RUN_ID]"

	ciop-copy -O $TMPDIR/runtime/topo $demfile
	[ "$?" != "0" ] && exit $ERR_NODEM

	ciop-log "INFO" "copying the DORIS files"
	for mydoris in `cat $input | grep "^.or=" | cut -d "=" -f 2-`
	do
		ciop-copy -O $TMPDIR/aux/ENVI/Doris $mydoris
		[ "$?" != "0" ] && exit $ERR_AUX
	done
	 
	ciop-log "INFO" "copying ASAR aux"
	for myaux in `cat $input | grep "^aux=" | cut -d "=" -f 2-`
	do
		ciop-copy -O $TMPDIR/aux/ENVI/ASA_INS $myaux
		[ "$?" != "0" ] && exit $ERR_AUX
	done
	
	# create the list of ASA_INS_AX
	ls $TMPDIR/aux/ENVI/ASA_INS/ASA_INS* | sed 's#.*/\(.*\)#\1#g' > $TMPDIR/aux/ENVI/ASA_INS/list
#	ls ASA_INS* > $TMPDIR/aux/ENVI/ASA_INS/list

	cd $TMPDIR

	# get the references to master and slave
	master=`cat $input | grep "^master=" | cut -d "=" -f 2-`
	slave=`cat $input | grep "^slave=" | cut -d "=" -f 2-`

	cd $TMPDIR/runtime/raw
	
	# Get the master
	ciop-log "INFO" "retrieving the master from $master"
	master=`ciop-copy -O $TMPDIR/runtime/raw $master`
	[ -z "$master" ] && exit $ERR_NOMASTERFILE

	[[ $master == *CEOS* ]] && {
		# ERS2 in CEOS format
		tar --extract --file=$master -O DAT_01.001 > master.dat
		tar --extract --file=$master -O LEA_01.001 > master.ldr
		[ ! -e $TMPDIR/runtime/raw/master.dat ] && exit $ERR_NOCEOS
		[ ! -e $TMPDIR/runtime/raw/master.ldr ] && exit $ERR_NOCEOS
	 } || {
		# ENVISAT ASAR in N1 format
		ln -s $master master.baq
	}

	ciop-log "INFO" "retrieving the slave from $slave"
	slave=`ciop-copy -O $TMPDIR/runtime/raw $slave`
	[ -z "$slave" ] && exit $ERR_NOSLAVEFILE

	[[ $slave == *CEOS* ]] && {	
		tar --extract --file=$slave -O DAT_01.001 > $TMPDIR/runtime/raw/slave.dat
		tar --extract --file=$slave -O LEA_01.001 > $TMPDIR/runtime/raw/slave.ldr
		flag="ers"
	} || { 	
		# ENVISAT ASAR in N1 format
		ln -s $slave $TMPDIR/runtime/raw/slave.baq
		flag="envi"
	}

	result=`echo "${master}_${slave}" | sed 's#.*/\(.*\)\.N1_.*/\(.*\)\.N1#\1_\2#g'`

	ciop-log "INFO"	"starting GMTSAR with $result"
	csh $_CIOP_APPLICATION_PATH/gmtsar/libexec/run_${flag}.csh & #> $TMPDIR/runtime/${result}_envi.log &
	wait ${!}			

	# publish results and logs
	ciop-log "INFO" "publishing log files"
	ciop-publish -m $TMPDIR/runtime/${result}_${flag}.log
	
	ciop-log "INFO" "result packaging"
	mydir=$( ls $TMPDIR/runtime/intf/ | sed 's#.*/\(.*\)#\1#g' )

	ciop-log "DEBUG" "outputfolder is: $TMPDIR/runtime/intf + $mydir"

	cd $TMPDIR/runtime/intf/$mydir

	#creates the tiff files
	for mygrd in `ls *ll.grd`; do gdal_translate $mygrd `echo $mygrd | sed 's#\.grd#.tiff#g'`; done
	for mygrd in `ls *.grd`; do gzip -9 $mygrd; done
        
	cd $TMPDIR/runtime/intf

	ciop-log "INFO" "publishing results"
	for myext in `echo "png ps gz tiff"`
	do
		ciop-publish -b $TMPDIR/runtime/intf -m ${mydir}/*.$myext
	done
	
	ciop-log "INFO" "cleanup"
	
	[ -d "$TMPDIR" ] && {
		rm -fr $TMPDIR/runtime/raw/*
		rm -fr $TMPDIR/runtime/intf/*
	}	

done

exit $SUCCESS
