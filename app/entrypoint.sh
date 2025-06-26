#!/bin/bash

# LinuxServer.io style entrypoint for Roon Server
# Handles PUID/PGID user mapping at runtime

set -e

# Default values
USER_ID=${PUID:-911}
GROUP_ID=${PGID:-911}

echo "
-------------------------------------
User uid:    ${USER_ID}
User gid:    ${GROUP_ID}
-------------------------------------
"

# Create or update the abc user and group with the specified PUID/PGID
groupmod -o -g "${GROUP_ID}" abc
usermod -o -u "${USER_ID}" abc

# Ensure abc user is in audio group
usermod -aG audio abc

echo "Setting ownership of directories..."

# Set ownership of important directories
chown -R abc:abc \
    /opt/RoonServer \
    /var/roon \
    /config \
    /logs 2>/dev/null || true

# Don't change ownership of /music if it's a bind mount (could be large)
# Instead just ensure abc can read it
if [ -d "/music" ]; then
    # Only change if not already owned by abc or if it's empty
    if [ -z "$(ls -A /music)" ] || [ "$(stat -c '%u' /music)" = "0" ]; then
        chown abc:abc /music 2>/dev/null || echo "Warning: Could not change ownership of /music"
    fi
fi

echo "Setting up Roon environment..."

# Export environment variables for the Roon process
export ROON_DATAROOT="${ROON_DATAROOT:-/opt/RoonServer}"
export ROON_ID_DIR="${ROON_ID_DIR:-/opt/RoonServer}"
export DISPLAY="${DISPLAY:-:0.0}"

# Check if Roon Server is already downloaded
if [ ! -f "/opt/RoonServer/start.sh" ]; then
    echo "Roon Server not found. Downloading..."
    
    # Create temporary directory for download
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"
    
    # Download latest Roon Server
    echo "Downloading Roon Server..."
    wget -q "https://download.roonlabs.com/builds/RoonServer_linuxx64.tar.bz2" -O RoonServer_linuxx64.tar.bz2
    
    # Extract to temporary location first
    echo "Extracting Roon Server..."
    tar -xvj --overwrite -C RoonServer_linuxx64.tar.bz2
    # tar -xjf RoonServer_linuxx64.tar.bz2
    
    # Move extracted contents to final location
    # The tarball typically extracts to a RoonServer directory
    if [ -d "RoonServer" ]; then
        cp -r RoonServer/* /opt/RoonServer/
    else
        # Handle case where extraction doesn't create subdirectory
        cp -r * /opt/RoonServer/
    fi
    
    # Set proper ownership
    chown -R abc:abc /opt/RoonServer
    
    # Cleanup
    cd /
    rm -rf "${TEMP_DIR}"
    
    echo "Roon Server download and extraction completed."
else
    echo "Roon Server found at /opt/RoonServer/start.sh"
fi

# Verify dependencies
echo "Verifying Roon Server dependencies..."
cd /opt/RoonServer
if ! gosu abc:abc ./check.sh; then
    echo "ERROR: Dependency check failed!"
    exit 1
fi

echo "Starting Roon Server using official start.sh script as user abc (${USER_ID}:${GROUP_ID})..."

# Start Roon Server using the official start.sh script
cd /opt/RoonServer
exec gosu abc:abc ./start.sh --debug

