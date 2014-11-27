#!/bin/bash

# source the ciop functions (e.g. ciop-log)
source ${ciop_job_include}

export PATH=${_CIOP_APPLICATION_PATH}/msd/bin:$PATH

# define the exit codes
SUCCESS=0
ERR_NOINPUT=1
ERR_NODEM=2
ERR_NOMASTER=5
ERR_NOMASTERWKT=8
ERR_NOMASTERFILE=10

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
     $ERR_NOCEOS)	msg="CEOS product not retrieved";;
     $ERR_NOSLAVEWKT)	msg="Slave WKT not retrieved";;
     $ERR_NOSLAVEFILE) msg="Slave not retrieved to local node";;
     *)             	msg="Unknown error";;
   esac
   [ "$retval" != "0" ] && ciop-log "ERROR" "Error $retval - $msg, processing aborted" || ciop-log "INFO" "$msg"
   exit $retval
}
trap cleanExit EXIT

# get the catalogue access point
cat_osd_root="`ciop-getparam aux_catalogue`"

function getAUXref() {
  local rdf=$1
  local ods=$2
  ciop-log "INFO" "rdf is $rdf"
  ciop-log "INFO" "ods is $ods"
  startdate="`ciop-casmeta -f "ical:dtstart" $rdf | tr -d "Z"`"
  stopdate="`ciop-casmeta -f "ical:dtend" $rdf | tr -d "Z"`"
  ciop-log "INFO" "startdate is $startdate"
  ciop-log "INFO" "stopdate is $stopdate"
  ciop-log "INFO" "opensearch-client -f Rdf -p time:start=$startdate -p time:end=$stopdate $ods"
  opensearch-client -v -f Rdf -p "time:start=$startdate" -p "time:end=$stopdate" $ods
}

function getAuxOrbList() {

   local rdf=$1
   local ods=$2
	for aux in ASA_CON_AX ASA_INS_AX ASA_XCA_AX ASA_XCH_AX
	do

		ciop-log "INFO" "Getting a reference to $aux"
		for url in `getAUXref $input $cat_osd_root/$aux/description`
		do
			ciop-log "INFO" "the url is $url"
			#pass the aux reference to the next node
			[ "$url" != "" ] && echo "aux="$url"" 
    done
  done
  # DOR_VOR_AX
  ciop-log "INFO" "Getting a reference to DOR_VOR_AX"
  ref=`getAUXref $input $cat_osd_root/DOR_VOR_AX/description`

  [ "$ref" != "" ] && echo "vor="$ref""

}


# Get the master - it's always the same
master="`ciop-getparam Level0_ref`"
[ -z "$master" ] && exit $ERR_NOMASTER 

echo "master="$master"" > $TMPDIR/joborder

getAuxOrbList $master $cat_osd_root >> $TMPDIR/joborder

# loop through all slaves
i=0
while read slave 
do
   cp $TMPDIR/joborder $TMPDIR/joborder_${i}.tmp
   echo "slave="$slave"" >> $TMPDIR/joborder_${i}.tmp

   getAuxOrbList $slave $cat_osd_root >> $TMPDIR/joborder_${i}.tmp

   sort -u $TMPDIR/joborder_${i}.tmp > $TMPDIR/joborder_${i}
   ciop-publish $TMPDIR/joborder_${i}	
   
   rm -f $TMPDIR/joborder_${i}.tmp $TMPDIR/joborder_${i}
   i++ 
done

