#!/usr/bin/env bash

set -e

ROON_PACKAGE_URI=http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2
ROON_PACKAGE_NAME=RoonServer
ROON_PACKAGE_DEST=/opt

BUILD_DIR=./build

mkdir -p build
pushd build
wget http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2
tar -xvf RoonServer_linuxx64.tar.bz2
popd

docker build . -t elgeeko/roon-server:latest 
