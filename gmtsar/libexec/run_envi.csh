#!/bin/csh -fx

cd $TMPDIR/runtime

#source ${_CIOP_APPLICATION_PATH}/GMTSAR/gmtsar_config

p2p_ENVI.csh master slave ${_CIOP_APPLICATION_PATH}/GMTSAR/gmtsar/csh/config.envi.txt
