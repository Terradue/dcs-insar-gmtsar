#!/bin/csh -fx

cd $TMPDIR/runtime

source ${_CIOP_APPLICATION_PATH}/share1/gmtsar/gmtsar_config

p2p_ERS.csh master slave ${_CIOP_APPLICATION_PATH}/share1/gmtsar/csh/config.ers.txt
