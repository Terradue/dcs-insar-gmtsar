#!/bin/bash

# source the ciop functions (e.g. ciop-log)
source ${ciop_job_include}

export OS=`uname -p`
export GMTHOME=/usr
export NETCDFHOME=/usr
export GMTSARHOME=/usr/local/GMTSAR
export GMTSAR=$GMTSARHOME/gmtsar
export PATH=$GMTSAR/bin:$GMTSAR/csh:$GMTSARHOME/preproc/bin:$GMTSARHOME/ENVISAT_preproc/bin/:$PATH

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
function cleanExit ()
{
   local retval=$?
   local msg=""
   case "$retval" in
     $SUCCESS)      	msg="Processing successfully concluded";;
     $ERR_NOMASTER) 	msg="Master reference not provided";;
     $ERR_NOMASTERWKT) 	msg="Master WKT not retrieved";;
     $ERR_NOMASTERFILE)	msg="Master not retrieved to local node";;	
     $ERR_NODEM)    	msg="DEM not retrieved";;
     $ERR_AUX)          msg="Failed to retrieve auxiliary and/or orbital data";;
     $ERR_NOCEOS)	msg="CEOS product not retrieved";;
     $ERR_NOSLAVEFILE) msg="Slave not retrieved to local node";;
     *)             	msg="Unknown error";;
   esac
   [ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
   exit $retval
}
trap cleanExit EXIT

# create environment
mkdir -p $TMPDIR/runtime/raw $TMPDIR/runtime/topo $TMPDIR/runtime/log &> /dev/null
mkdir -p $TMPDIR/aux

first="true"
while read input
do
set -x
    refs=`ciop-copy -o $TMPDIR $input`
    # get the DEM for the first time
    [ "$first" == "true" ] && {
      ciop-log "INFO" "Retrieve DEM"	 
      demurl=`cat $refs | egrep -v '(aux=|vor=|slave=|master=)' | cut -d "=" -f 2-`
      echo $demurl | ciop-copy -o $TMPDIR/runtime/topo -
      	
      [ "$?" != "0" ] && exit $ERR_NODEM
      ciop-log "DEBUG" "`tree $TMPDIR/runtime/topo`"
      first="false"
    }
   set +x
    # get the aux and orbital data
    cat $refs | egrep -v '(dem=|slave=|master=)' | while read url
    do
      ciop-log "INFO" "Getting $url"
      ciop-copy -o $TMPDIR/aux `echo $url | cut -d "=" -f 2`
      [ "$?" != "0" ] && exit $ERR_AUX
    done 
    
    export ORBITS=$TMPDIR/aux

    # get the references to master and slave
    master=`cat $refs | grep "master=" | cut -d "=" -f 2`
    slave=`cat $refs | grep "slave=" | cut -d "=" -f 2`
	
    # Get the master
    ciop-log "INFO" "Retrieve $master from archive"
    # from reference to local path
    master=`echo $master | ciop-copy -o $TMPDIR/runtime/raw -`

    ciop-log "DEBUG" "master: $master"
    [ -z "$master" ] && exit $ERR_NOMASTERFILE

	 cd $TMPDIR/runtime/raw
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

	ciop-log "INFO" "Retrieve slave $slave from archive"
	slave=`echo $slave | ciop-copy -o $TMPDIR/runtime/raw -`
	[ -z "$slave" ] && exit $ERR_NOSLAVEFILE

	ciop-log "INFO" "GMTSAR processing for slave `basename $slave`"
	# ERS2 in CEOS format
	[[ $slave == *CEOS* ]] && {	
		tar --extract --file=$slave -O DAT_01.001 > $TMPDIR/runtime/raw/slave.dat
      tar --extract --file=$slave -O LEA_01.001 > $TMPDIR/runtime/raw/slave.ldr
		result=`echo "${master}_${slave}" | sed 's#.*/\(.*\)\.N1_.*/\(.*\)\.N1#\1_\2#g'`
		csh $_CIOP_APPLICATION_PATH/gmtsar/libexec/run_ers.csh &> $TMPDIR/runtime/$(result)_ers.log
		ciop-publish -m $TMPDIR/runtime/$(result)_ers.log
	} || { 	
		set -x
        	# ENVISAT ASAR in N1 format
		ln -s $slave $TMPDIR/runtime/raw/slave.baq
		result=`echo "${master}_${slave}" | sed 's#.*/\(.*\)\.N1_.*/\(.*\)\.N1#\1_\2#g'`
		csh $_CIOP_APPLICATION_PATH/gmtsar/libexec/run_envi.csh & #> $TMPDIR/runtime/${result}_envi.log &
		wait ${!}			

		ciop-log "INFO" "Publishing log"
		ciop-publish -m $TMPDIR/runtime/${result}_envi.log
		set +x
		exit 1	
       }

	# publish results and logs
	ciop-log "INFO" "result packaging"
	
	cd $TMPDIR/runtime/intf
	
	tar vcfzh $result.tgz . 1>&2 #&> /dev/null

	ciop-log "INFO" "publish results and logs"
	ciop-publish -m $TMPDIR/runtime/intf/$result.tgz
	
	ciop-log "INFO" "cleanup"
	
	[ -d "$TMPDIR" ] && {
		cd $TMPDIR/runtime/raw
		rm -f *

		cd $TMPDIR/runtime/intf
		rm -fr *

	}	

done

