# SPDX-FileCopyrightText: (c) 2021-2025 Jeff C. Jensen
# SPDX-License-Identifier: MIT

# syntax=docker/dockerfile:1

ARG BUILDKIT_SBOM_SCAN_CONTEXT=true
ARG BUILDKIT_SBOM_SCAN_STAGE=true
ARG BASEIMAGE=noble-20250716

##################
## base stage
##################
FROM ubuntu:${BASEIMAGE} AS base

USER root

# Preconfigure debconf for non-interactive installation - otherwise complains about terminal
# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=localhost:0.0
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# configure python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# configure apt
RUN apt update -q
RUN apt install --no-install-recommends -y -q ca-certificates

# install prerequisites
# Roon prerequisites:
#  - Roon requirements: ffmpeg libasound2-dev
#  - Roon access samba mounts: cifs-utils
#  - Roon play to local audio device: alsa
#  - Query USB devices inside Docker container: usbutils udev libudev1
RUN apt install --no-install-recommends -y -q ffmpeg libasound2-dev alsa
RUN apt install --no-install-recommends -y -q cifs-utils
RUN apt install --no-install-recommends -y -q usbutils udev libudev1
# app prerequisites
#  - Docker healthcheck: curl
#  - App entrypoint downloads Roon: wget bzip2
#  - set timezone: tzdata
RUN apt install --no-install-recommends -y -q curl wget bzip2
RUN apt install --no-install-recommends -y -q tzdata

# apt cleanup
RUN apt autoremove -y -q
RUN apt clean -y -q
RUN rm -rf /var/lib/apt/lists/*

####################
## application stage
####################
FROM scratch
COPY --from=base / /

LABEL maintainer="elgeeko1"
LABEL source="https://github.com/elgeeko1/roon-server-docker"
LABEL org.opencontainers.image.title="Roon Server"
LABEL org.opencontainers.description="Roon Server"
LABEL org.opencontainers.image.authors="Jeff C. Jensen <11233838+elgeeko1@users.noreply.github.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="1.1.0"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/elgeeko/roon-server"
LABEL org.opencontainers.image.source="https://github.com/elgeeko1/roon-server-docker"

# Roon documented ports
#  - multicast (discovery?)
EXPOSE 9003/udp
#  - Roon API and RAAT server
#    see https://community.roonlabs.com/t/roon-api-on-build-880-connection-refused-error/181619/3
#    - RAAT server typically :9200
EXPOSE 9100-9200/tcp
# Chromecast devices
EXPOSE 30000-30010/tcp

# See https://github.com/elgeeko1/roon-server-docker/issues/5
# https://community.roonlabs.com/t/what-are-the-new-ports-that-roon-server-needs-open-in-the-firewall/186023/16
#   remoting/brokerserver (i.e. 9332), and Roon Display (i.e. 9330)
EXPOSE 9093/udp
EXPOSE 9330-9339/tcp

# Roon Arc
EXPOSE 55000/tcp

VOLUME ["/opt/RoonServer", "/var/roon", "/music"]

USER root

# change to match your local zone.
# matching container to host timezones synchronizes
# last.fm posts, filesystem write times, and user
# expectations for times shown in the Roon client.
ARG TZ="America/Los_Angeles"
ENV TZ=${TZ}
RUN echo "${TZ}" > /etc/timezone \
	&& ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
	&& dpkg-reconfigure -f noninteractive tzdata

# non-root container user.
# you may want to randomize the UID to prevent
# accidental collisions with the host filesystem;
# however, this may prevent the container from
# accessing network shares that are not public,
# or if the RoonServer build is mapped in from
# the host filesystem.
ARG CONTAINER_USER=ubuntu
ARG CONTAINER_USER_UID=1000
RUN if [ "${CONTAINER_USER}" != "ubuntu" ]; \
	then useradd \
		--uid ${CONTAINER_USER_UID} \
		--user-group \
		${CONTAINER_USER}; \
	fi
RUN usermod -aG audio ${CONTAINER_USER}

# copy application files
COPY --chmod=0755 app/entrypoint.sh /entrypoint.sh
COPY README.md /README.md

# configure filesystem
## map a volume to this location to retain Roon Server data
RUN mkdir -p /opt/RoonServer \
	&& chown ${CONTAINER_USER}:${CONTAINER_USER} /opt/RoonServer
## map a volume to this location to retain Roon Server cache
RUN mkdir -p /var/roon \
	&& chown ${CONTAINER_USER}:${CONTAINER_USER} /var/roon

# create /music directory (users may override with a volume)
RUN mkdir -p /music \
	&& chown ${CONTAINER_USER}:${CONTAINER_USER} /music \
	&& chmod og+r /music

USER ${CONTAINER_USER}

# entrypoint
# set environment variables consumed by RoonServer
# startup script
ENV DISPLAY=localhost:0.0
ENV ROON_DATAROOT=/var/roon
ENV ROON_ID_DIR=/var/roon

ENTRYPOINT ["/entrypoint.sh"]
HEALTHCHECK --start-period=30s --interval=5m --timeout=5s \
	CMD curl -f http://localhost:9330/display
