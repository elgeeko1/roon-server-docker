FROM ubuntu:groovy
LABEL maintainer="https://github.com/elgeeko1"

USER root

EXPOSE 9003/udp
EXPOSE 9100-9200/tcp
EXPOSE 49863/tcp
EXPOSE 52667/tcp
EXPOSE 52709/tcp
EXPOSE 63098-63100/tcp

ARG ROON_SERVER_SRC=./build/RoonServer

ENV ROON_DATAROOT=/var/roon
ENV ROON_ID_DIR=/var/roon
VOLUME ["/var/roon"]
VOLUME ["/music"]

# Preconfigure debconf for non-interactive installation - otherwise complains about terminal
# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
ARG DEBIAN_FRONTEND=noninteractive
ENV DISPLAY localhost:0.0
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
	&& dpkg-divert --local --rename --add /sbin/initctl \
	&& ln -sf /bin/true /sbin/initctl \
	&& echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# set timezone (for interactive environments)
RUN apt-get update -q \
  && apt-get install -y -q -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" tzdata \
	&& echo "US/Pacific" > /etc/timezone \
	&& ln -fs /usr/share/zoneinfo/US/Pacific-New /etc/localtime \
	&& dpkg-reconfigure -f noninteractive tzdata \
  && apt-get -q -y autoremove \
  && apt-get -q -y clean \
	&& rm -rf /var/lib/apt/lists/*

# update packages
RUN apt-get update -q \
  && apt-get -q -y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" install apt-utils \
  && apt-get -q -y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" upgrade \
  && apt-get -q -y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" dist-upgrade \
  && apt-get -q -y autoremove \
  && apt-get -q -y clean \
  && rm -rf /var/lib/apt/lists/*

# install Roon prerequisites:
#  - Roon requirements: ffmpeg libasound2 cifs-utils
#  - Docker healthcheck: curl
#  - Query USB devices inside Docker container: usbutils udev
RUN apt-get update -q \
  && apt-get install -y -q -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" ffmpeg libasound2 cifs-utils curl usbutils udev \
  && apt-get -q -y autoremove \
  && apt-get -q -y clean \
	&& rm -rf /var/lib/apt/lists/*

# copy RoonServer package
COPY ${ROON_SERVER_SRC} /opt/RoonServer

ENTRYPOINT ["/opt/RoonServer/start.sh"]

# curl the Roon display to verify Roon is running
HEALTHCHECK --interval=1m --timeout=1s --start-period=5s \
   CMD curl -f http://localhost:9100/display/ || exit 1
