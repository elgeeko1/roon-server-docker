#!/bin/bash

ROON_PACKAGE_URI=${ROON_PACKAGE_URI-"http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2"}

echo Starting RoonServer with user `whoami`

# install Roon if not present
if [ ! -f /opt/RoonServer/start.sh ]; then
  echo Downloading Roon Server from ${ROON_PACKAGE_URI}
  wget --progress=bar:force --tries=2 -O - ${ROON_PACKAGE_URI} | tar -xvj --overwrite -C /opt
  if [ $? != 0 ]; then
    echo Error: Unable to install Roon Server.
    exit 1
  fi
fi

echo Verifying Roon installation
/opt/RoonServer/check.sh
retval=$?
if [ ${retval} != 0 ]; then
  echo Verification of Roon installation failed.
  exit ${retval}
fi

# start Roon
#
# since we're invoking from a script, we need to
# catch signals to terminate Roon nicely
/opt/RoonServer/start.sh &
roon_start_pid=$!
trap 'kill -INT ${roon_start_pid}' SIGINT SIGQUIT SIGTERM
wait "${roon_start_pid}" # block until Roon terminates
retval=$?
exit ${retval}
