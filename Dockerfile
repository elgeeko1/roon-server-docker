##################
## base stage
##################
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION} AS base

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ="Europe/Amsterdam"

# Set timezone early to avoid interactive prompts
ENV TZ=${TZ}
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Configure apt for non-interactive installation
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    dpkg-divert --local --rename --add /sbin/initctl && \
    ln -sf /bin/true /sbin/initctl && \
    echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d && \
    chmod +x /usr/sbin/policy-rc.d

# Update package lists and install essential packages in single layer
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        apt-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

##################
## Dependencies stage
##################
FROM base AS dependencies

# Install all dependencies in single optimized layer
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        # Roon core requirements
        ffmpeg \
        libasound2t64 \
        libasound2-data \
        libasound2-plugins \
        # Network and filesystem access
        cifs-utils \
        # USB and audio device access
        udev \
        # Application utilities
        curl \
        wget \
        bzip2 \
        tzdata \
        # Process management
        procps \
        # User management requirements
        passwd \
        sudo \
        gosu && \
    # Clean up in same layer to reduce image size
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

##################
## Runtime stage
##################
FROM dependencies AS runtime

LABEL maintainer="elgeeko1" \
      source="https://github.com/elgeeko1/roon-server-docker" \
      org.opencontainers.image.title="Roon Server" \
      org.opencontainers.image.description="Roon Music Server in Docker" \
      org.opencontainers.image.source="https://github.com/elgeeko1/roon-server-docker"

# Create abc user/group (LinuxServer standard)
RUN groupadd -g 911 abc && \
    useradd -u 911 -g 911 -d /config -s /bin/bash abc && \
    usermod -G users abc && \
    usermod -aG audio abc

# Create directories that need proper ownership
RUN mkdir -p \
        /opt/RoonServer \
        /var/roon \
        /music \
        /config \
        /logs \
        /app && \
    chown -R abc:abc \
        /opt/RoonServer \
        /var/roon \
        /music \
        /config \
        /logs \
        /app

# Copy application files
COPY app/entrypoint.sh /entrypoint.sh
COPY README.md /README.md

# Make scripts executable
RUN chmod +x /entrypoint.sh

# Set runtime environment variables
ENV HOME="/config" \
    ROON_DATAROOT="/opt/RoonServer" \
    ROON_ID_DIR="/opt/RoonServer" \
    DISPLAY=":0.0" \
    PATH="/opt/RoonServer:${PATH}" \
    PUID=911 \
    PGID=911

# Expose ports in logical groups
# Core Roon services
EXPOSE 9330-9339/tcp
# RAAT (Roon Advanced Audio Transport)
EXPOSE 9003/udp 9100-9200/tcp
# Discovery and control
EXPOSE 9001-9002/tcp 9200/tcp
# Chromecast support
EXPOSE 30000-30010/tcp
# Additional documented ports
EXPOSE 49863/tcp 52667/tcp 52709/tcp 63098-63100/tcp

# Health check using specific Roon endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9330/display || exit 1

# Use entrypoint (will handle PUID/PGID setup)
ENTRYPOINT ["/entrypoint.sh"]

##################
## Development stage (optional)
##################
FROM runtime AS development

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        vim \
        htop \
        strace \
        net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 
