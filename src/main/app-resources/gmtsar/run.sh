#!/bin/bash

# source the ciop functions (e.g. ciop-log)
source ${ciop_job_include}

export OS=`uname -p`
export GMTHOME=/usr
export NETCDFHOME=/usr
export GMTSARHOME=/usr/local/GMTSAR
export GMTSAR=$GMTSARHOME/gmtsar
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
    $SUCCESS)      	    msg="Processing successfully concluded";;
    $ERR_NOMASTER) 	    msg="Master reference not provided";;
    $ERR_NOMASTERWKT) 	msg="Master WKT not retrieved";;
    $ERR_NOMASTERFILE)	msg="Master not retrieved to local node";;	
    $ERR_NODEM)    	    msg="DEM not retrieved";;
    $ERR_AUX)           msg="Failed to retrieve auxiliary and/or orbital data";;
    $ERR_NOCEOS)	      msg="CEOS product not retrieved";;
    $ERR_NOSLAVEFILE)   msg="Slave not retrieved to local node";;
    *)             	    msg="Unknown error";;
  esac
  [ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
  exit $retval
}
trap cleanExit EXIT

export TMPDIR=/tmp/`uuidgen`
# create environment
mkdir -p $TMPDIR/runtime/raw $TMPDIR/runtime/topo $TMPDIR/runtime/log &> /dev/null
mkdir -p $TMPDIR/aux/ENVI/ASA_INS
mkdir -p $TMPDIR/aux/ENVI/Doris

export ORBITS=$TMPDIR/aux

first="true"
while read input
do
  refs=`ciop-copy -o $TMPDIR $input`
  # get the DEM for the first time
  [ "$first" == "true" ] && {
    ciop-log "INFO" "Retrieve DEM"	 
    demurl=`cat $refs | egrep -v '(aux=|vor=|slave=|master=)'`
    echo ${demurl#dem=} | ciop-copy -o $TMPDIR/runtime/topo -
    
    [ "$?" != "0" ] && exit $ERR_NODEM
    ciop-log "DEBUG" "`tree $TMPDIR/runtime/topo`"
    first="false"
  }
    
  # get the aux and orbital data
  cat $refs | egrep -v '(dem=|slave=|master=|aux=)' | while read url
  do
    ciop-log "INFO" "Getting $url"
    echo ${url#dor=} | ciop-copy -o $TMPDIR/aux/ENVI/Doris -`
    [ "$?" != "0" ] && exit $ERR_AUX
  done 
   
  cat $refs | egrep -v '(dem=|slave=|master=|dor=)' | while read url
  do
    ciop-log "INFO" "Getting $url"
    echo ${url#aux=} | ciop-copy -o $TMPDIR/aux/ENVI/ASA_INS -`
    [ "$?" != "0" ] && exit $ERR_AUX
  done
  # create the list of ASA_INS_AX
  ls ASA_INS* > $TMPDIR/aux/ENVI/ASA_INS/list
  cd $TMPDIR

  # get the references to master and slave
  master=`cat $refs | egrep -v '(dem=|dor=|aux=|slave=)'`
  slave=`cat $refs | egrep -v '(dem=|dor=|aux=|master=)'`
	
  # Get the master
  ciop-log "INFO" "Retrieve $master from archive"
  master=`echo ${master#master=} | ciop-copy -o $TMPDIR/runtime/raw -`
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
  slave=`echo ${slave#slave=} | ciop-copy -o $TMPDIR/runtime/raw -`
  [ -z "$slave" ] && exit $ERR_NOSLAVEFILE

  ciop-log "INFO" "GMTSAR processing for slave `basename $slave`"
  # ERS2 in CEOS format
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
  csh $_CIOP_APPLICATION_PATH/gmtsar/libexec/run_${flag}.csh & #> $TMPDIR/runtime/${result}_envi.log &
  wait ${!}			

  # publish results and logs
  ciop-publish -m $TMPDIR/runtime/${result}_${flag}.log
  
  ciop-log "INFO" "result packaging"
  cd $TMPDIR/runtime/intf
  
  tar -C $TMPDIR/runtime/intf -fzh $result.tgz . 
  
  ciop-log "INFO" "publish results and logs"
  ciop-publish -m $TMPDIR/$result.tgz
  
  ciop-log "INFO" "cleanup"
  
  [ -d "$TMPDIR" ] && {
    rm -fr $TMPDIR/runtime/raw/*
    rm -fr $TMPDIR/runtime/intf/*
  }	

done
