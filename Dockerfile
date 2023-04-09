##################
## base stage
##################
FROM ubuntu:jammy AS BASE

USER root

# Preconfigure debconf for non-interactive installation - otherwise complains about terminal
# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
ARG DEBIAN_FRONTEND=noninteractive
ARG DISPLAY localhost:0.0
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# configure apt
RUN apt-get update -q
RUN apt-get install --no-install-recommends -y -q apt-utils 2>&1 \
	| grep -v "debconf: delaying package configuration"
RUN apt-get install --no-install-recommends -y -q ca-certificates

# install prerequisites
# Roon prerequisites:
#  - Roon requirements: ffmpeg libasound2 libicu70
#  - Roon access samba mounts: cifs-utils
#  - Roon play to local audio device: alsa
#  - Query USB devices inside Docker container: usbutils udev
RUN apt-get install --no-install-recommends -y -q ffmpeg
RUN apt-get install --no-install-recommends -y -q libasound2
RUN apt-get install --no-install-recommends -y -q libicu70
RUN apt-get install --no-install-recommends -y -q cifs-utils
RUN apt-get install --no-install-recommends -y -q alsa
RUN apt-get install --no-install-recommends -y -q usbutils
RUN apt-get install --no-install-recommends -y -q udev
# app prerequisites
#  - Docker healthcheck: curl
#  - App entrypoint downloads Roon: wget bzip2
#  - set timezone: tzdata
RUN apt-get install --no-install-recommends -y -q curl
RUN apt-get install --no-install-recommends -y -q wget
RUN apt-get install --no-install-recommends -y -q bzip2
RUN apt-get install --no-install-recommends -y -q tzdata

# apt cleanup
RUN apt-get autoremove -y -q
RUN apt-get -y -q clean
RUN rm -rf /var/lib/apt/lists/*

####################
## application stage
####################
FROM scratch
COPY --from=BASE / /
LABEL maintainer="elgeeko1"
LABEL source="https://github.com/elgeeko1/roon-server-docker"

# Roon documented ports
#  - multicast (discovery?)
EXPOSE 9003/udp
#  - Roon Display
EXPOSE 9100/tcp
#  - RAAT
EXPOSE 9100-9200/tcp
#  - Roon events from cloud to core (websocket?)
EXPOSE 9200/tcp

# ports experimentally determined; or, documented
# somewhere and source forgotten; or, commented
# in a forum without explanation. I swear I know
# what these ports do but I've run out of space
# in the margin to write the solution. Either way
# there are no other services running in the
# container that should bind to these ports,
# so exposing them shouldn't pose a security risk.
EXPOSE 9001-9002/tcp
EXPOSE 49863/tcp
EXPOSE 52667/tcp
EXPOSE 52709/tcp
EXPOSE 63098-63100/tcp

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
ARG CONTAINER_USER=roon
ARG CONTAINER_USER_UID=1000
RUN adduser --disabled-password --gecos "" --uid ${CONTAINER_USER_UID} ${CONTAINER_USER}

# add container user to audio group
RUN usermod -a -G audio ${CONTAINER_USER}

# copy application files
COPY app/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY README.md /README.md

# configure filesystem
## map a volume to this location to retain Roon Server data
RUN mkdir -p /opt/RoonServer \
	&& chown ${CONTAINER_USER} /opt/RoonServer \
	&& chgrp ${CONTAINER_USER} /opt/RoonServer
## map a volume to this location to retain Roon Server cache
RUN mkdir -p /var/roon \
		&& chown ${CONTAINER_USER} /var/roon \
		&& chgrp ${CONTAINER_USER} /var/roon
# volume for local music library
VOLUME ["/music"]

USER ${CONTAINER_USER}

# entrypoint
# set environment variables consumed by RoonServer
# startup script
ENV DISPLAY localhost:0.0
ENV ROON_DATAROOT=/var/roon
ENV ROON_ID_DIR=/var/roon
ENTRYPOINT ["/entrypoint.sh"]
