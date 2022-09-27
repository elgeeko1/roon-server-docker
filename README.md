# Roon Sever in Docker
Roon Server in a docker container.

### Features
- Downloads and installs latest Roon Server on first container start
- Audio input from a local music library
- Audio input from Tidal or Qobuz
- Audio output to USB DAC devices connected to the Roon Server host
- Audio output to RAAT devices such as the Roon app, Roon Bridge,
RoPieee, etc.
- Audio output to local audio output on the Roon Server host
- Local timezone support for accurate last.fm tagging
- Persistent cache
- Secure execution (unprivileged execution, macvlan network)
  - Privileged execution mode and host network are supported

# Running

## Install prerequisites on the host
Install the following audio packages into your host:
```sh
apt-get install alsa-utils libasound2 libasound2-data libasound2-plugins
```

## Create persistent data directories in host filesystem
The commands below require the following folders exist in your host filesystem:
- `data` on your host which will be used for Roon's persistent storage. Example: `/home/myuser/roon/data`.
- `music` on your host while which contains your local music library. Example: `/home/myuser/roon/music`.
  - This folder can also be used as a Samba or NFS share for network access to your library.
  - This folder is optional. Omit if you plan to exclusively stream music.

Create the persistent data directories in the host filesystem:
```sh
mkdir -p ~/roon
mkdir -p ~/roon/data
mkdir -p ~/roon/music
```

## Option 1: Run in least secure mode (easiest)
Run using privileged execution mode and host network mode:
```sh
docker run \
  --name roon-server \
  --volume ~/roon/data:/var/roon \
  --volume ~/roon/music:/music:ro \
  --network host \
  --privileged \
  elgeeko/roon-server
```

## Option 2: Run in macvlan mode (more secure)
Run in an unprivileged container using macvlan network mode. Replace the subnet, gateway and IP address to match your local network.

### Create docker macvlan network
```sh
docker network create \
  --driver macvlan \
  --subnet 192.168.1.0 \
  --gateway 192.168.1.1 \
  -o parent=eth0 \
  roon
```

### Run using unprivileged execution mode and macvlan network mode
```sh
docker run \
  --name roon-server \
  --publish_all \
  --volume ~/roon/data:/var/roon \
  --volume ~/roon/music:/music:ro \
  --network roon \
  --ip 192.168.1.2 \
  elgeeko/roon-server
```

## Option 3: Bridge mode
This works but with a significant limitation. Docker containers on bridged networks
don't receive broadcast or multicast communication, which is used by Roon Server
to discover RAAT devices such as Roon Bridge or RoPieee. Hence, Roon Server is
limited to USB DACs or your Roon App on your PC.

See the Dockerfile source below for ports to open. See Docker documentation for
creating and using a bridged network.

# Additional functionality

### Useful docker flags
You may optionally want to add the `-d` flag to output to syslog
instead of the console, and `--restart-unless-stopped` flag to
restart the container if it fails.

### Use USB DACs connected to the host
Add the following arguments to the `docker run` command:  
`--volume /usr/share/alsa:/usr/share/alsa` - allow Roon to access ALSA cards  
`--volume /run/udev:/run/udev:ro` - allow Roon to enumerate USB devices  
`--device /dev/bus/usb` - allow Roon to access USB devices  
`--device /dev/snd` - allow Roon to access ALSA devices  

### Synchronize filesystem and last.fm timestamps with your local timezone
Add the following arguments to the `docker run` command:  
`--volume /etc/localtime:/etc/localtime:ro` - map local system clock to container clock  
`--volume /etc/timezone:/etc/timezone:ro` - map local system timezone to container timezone  

# Known Issues
- USB DACs connected to the system for the first time do not appear in Roon.
The workaround is to restart the container. Once the device has been initially
connected, disconnecting and reconnecting is reflected in Roon.
- Mounting network drives via cisfs may require root access. The workaround is to
run the container with the `user=root` option in the `docker run` command.

# Building from the Dockerfile
`docker build .`

# Resources
- [elgeeko/roon-server](https://hub.docker.com/repository/docker/elgeeko/roon-server) on Docker Hub
- Ansible script to deploy the Roon Server image, as well as an optional Samba server for network sharing of a local music library: https://github.com/elgeeko1/elgeeko1-roon-server-ansible
- Roon Labs Linux install instructions: https://help.roonlabs.com/portal/en/kb/articles/linux-install
