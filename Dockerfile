FROM ubuntu:20.04
LABEL maintainer="https://github.com/elgeeko1"

USER root

EXPOSE 9003/udp
EXPOSE 9100-9200/tcp
EXPOSE 49863/tcp
EXPOSE 52667/tcp
EXPOSE 52709/tcp
EXPOSE 63098-63100/tcp

ARG ROON_PACKAGE_URI=http://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2

# set timezone (for interactive environments)
RUN apt-get update -q \
  && apt-get install --no-install-recommends -y -q tzdata \
	&& echo "America/Los_Angeles" > /etc/timezone \
	&& ln -fs /usr/share/zoneinfo/US/Los_Angeles /etc/localtime \
	&& dpkg-reconfigure -f noninteractive tzdata \
  && apt-get -q -y clean \
	&& rm -rf /var/lib/apt/lists/*

# install Roon prerequisites:
#  - Roon requirements: ffmpeg libasound2 cifs-utils libicu66
#  - Docker healthcheck: curl
#  - Query USB devices inside Docker container: usbutils udev
RUN apt-get update -q \
  && apt-get install --no-install-recommends -y -q \
		ffmpeg \
		libasound2 \
		cifs-utils \
		curl \
		usbutils \
    udev \
  && apt-get -q -y clean \
	&& rm -rf /var/lib/apt/lists/*

# Download RoonServer package
RUN curl ${ROON_PACKAGE_URI} | tar -xvj -C /opt

# container user
ARG CONTAINER_USER=roon
ARG CONTAINER_USER_UID=1000
RUN adduser --disabled-password --gecos "" --uid ${CONTAINER_USER_UID} ${CONTAINER_USER} \
  && chown -R ${CONTAINER_USER} /opt/RoonServer \
  && chgrp -R ${CONTAINER_USER} /opt/RoonServer \
  && mkdir -p /var/roon \
  && chown -R ${CONTAINER_USER} /var/roon \
  && chgrp -R ${CONTAINER_USER} /var/roon

USER ${CONTAINER_USER}

ENV ROON_DATAROOT=/var/roon
ENV ROON_ID_DIR=/var/roon
VOLUME ["/var/roon"]
VOLUME ["/music"]

# curl the Roon display to verify Roon is running
HEALTHCHECK --interval=1m --timeout=1s --start-period=5s \
   CMD curl -f http://localhost:9100/display/ || exit 1

ENTRYPOINT ["/opt/RoonServer/start.sh"]
