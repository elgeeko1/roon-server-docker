#!/usr/bin/env bash

set -e

# enable docker BuildKit features
export DOCKER_BUILDKIT=1

ROON_PACKAGE_URI=http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2
ROON_PACKAGE_NAME=RoonServer
ROON_PACKAGE_DEST=/opt

BUILD_DIR=./build

# clear previous build files
if [ -d ${BUILD_DIR} ]; then
  echo removing previous build files
  rm -r ${BUILD_DIR}/*
fi

# download and extract Roon Server package
mkdir -p build
pushd build
wget http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2
tar -xvf RoonServer_linuxx64.tar.bz2
popd

docker build . --build-arg BUILDKIT_INLINE_CACHE=1
