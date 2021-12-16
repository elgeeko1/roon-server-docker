#!/bin/bash

ROON_PACKAGE_URI=${ROON_PACKAGE_URI-"http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2"}

# install Roon if not present
if [ ! -f /opt/RoonServer/start.sh ]; then
  echo Downloading Roon from ${ROON_PACKAGE_URI}
  wget \
    --show-progress \
    --tries=2 \
    -O /tmp/RoonServer_linuxx64.tar.bz2 \
    ${ROON_PACKAGE_URI}
  if [ ! $? ]; then
    echo Error: Unable to download Roon.
    exit 1
  fi

  echo Extracting Roon
  tar -xvjf /tmp/RoonServer_linuxx64.tar.bz2 -C /opt
  if [ ! $? ]; then
    echo Error: Unable to extract Roon.
    exit 2
  fi

  # cleanup
  rm /tmp/RoonServer_linuxx64.tar.bz2
fi

echo Verifying Roon installation
/opt/RoonServer/check.sh
retval=$?
if [ ! ${retval} ]; then
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
