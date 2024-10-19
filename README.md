# Roon Server in Docker
Roon Server in a docker container.

## Features

- Downloads and installs latest Roon Server on first container start
- Subsequent in-app Roon Server upgrades persist
- Audio input from a local music library
- Audio input from Tidal or Qobuz
- Audio output to USB DAC devices connected to the Roon Server host
- Audio output to RAAT devices such as the Roon app, Roon Bridge, RoPieee, etc.
- Audio output to local audio output on the Roon Server host
- Local timezone support for accurate last.fm tagging
- Persistent cache
- Secure execution (unprivileged execution, macvlan network)
  - Privileged execution mode and host network are supported

## Configure the Roon Host

### Install host prerequisites

Install the following audio packages into the host that will run Roon.

```bash
apt install alsa-utils libasound2 libasound2-data libasound2-plugins
```

### Create persistent data volumes and paths

Create persistent docker volumes to retain the binary installation of
Roon Server and its configuration across restarts of the service.

```bash
docker volume create roon-server-data
docker volume create roon-server-cache
```

Locate (or create) a folder to host your local music library. This step is optional and only needed if you have a local music library.
  - This folder can also be used as a Samba or NFS share for network access to your library.
  - This folder is optional. Omit if you plan to exclusively stream music.

Example:

```bash
mkdir -p ~/roon/music
```

## Run Roon

There are three ways to configure the Roon Docker container, each with different security levels. The first option is the easiest and simplest and should work for most users.

### Least secure mode (easiest)

This is the simplest way to run the docker container. Run using privileged execution mode and host network mode:

```bash
docker run \
  --name roon-server \
  --volume roon-server-data:/opt/RoonServer \
  --volume roon-server-cache:/var/roon \
  --volume ~/roon/music:/music:ro \
  --network host \
  --privileged \
  elgeeko/roon-server
```

### Run in macvlan mode (more secure)

Run in an unprivileged container using macvlan network mode. Replace the subnet, gateway, IP address, and primary ethernet adapter to match your local network.

#### Create docker macvlan network

```bash
docker network create \
  --driver macvlan \
  --subnet 192.168.1.0/24 \
  --gateway 192.168.1.1 \
  -o parent=eth0 \
  roon
```

### Run the container with the macvlan network

```bash
docker run \
  --name roon-server \
  --publish-all \
  --volume roon-server-data:/opt/RoonServer \
  --volume roon-server-cache:/var/roon \
  --volume ~/roon/music:/music:ro \
  --network roon \
  --ip 192.168.1.2 \
  elgeeko/roon-server
```

## Run the container in bridged mode

This option works but with a significant limitation. Docker containers on bridged networks don't receive broadcast or multicast communication, which is used by Roon Server
to discover RAAT devices such as Roon Bridge or RoPieee. Hence, Roon Server is
limited to USB DACs or your Roon App on your PC.

See the Dockerfile source below for ports to open. See Docker documentation for
creating and using a bridged network.

## Additional functionality

### Useful docker flags

You may optionally want to add the `-d` flag to output to syslog
instead of the console, and `--restart-unless-stopped` flag to
restart the container if it fails.

### Use USB DACs connected to the host

Add the following arguments to the `docker run` command:  
`--volume /run/udev:/run/udev:ro` - allow Roon to enumerate USB devices  
`--device /dev/bus/usb` - allow Roon to access USB devices (`/dev/usbmon0` for Fedora)   
`--device /dev/snd` - allow Roon to access ALSA devices   
`--group-add $(getent group audio | cut -d: -f3)` - add container user to host 'audio' group

### Synchronize filesystem and last.fm timestamps with your local timezone

Add the following arguments to the `docker run` command:  
`--volume /etc/localtime:/etc/localtime:ro` - map local system clock to container clock  
`--volume /etc/timezone:/etc/timezone:ro` - map local system timezone to container timezone  

## Known Issues

- USB DACs connected to the system for the first time do not appear in Roon.
The workaround is to restart the container. Once the device has been initially
connected, disconnecting and reconnecting is reflected in Roon.
- Mounting network drives via cisfs may require root access. The workaround is to
run the container with the `user=root` option in the `docker run` command.
- Fedora CoreOS sets a system paramenter `ulimit` to a smaller value than Roon
requires. Add the following argument to the `docker run` command:   
`--ulimit nofile=8192`

## Building from the Dockerfile

`docker build .`

## Resources

- [elgeeko/roon-server](https://hub.docker.com/repository/docker/elgeeko/roon-server) on Docker Hub
- Ansible script to deploy the Roon Server image, as well as an optional Samba server for network sharing of a local music library: https://github.com/elgeeko1/elgeeko1-roon-server-ansible
- Roon Labs Linux install instructions: https://help.roonlabs.com/portal/en/kb/articles/linux-install
