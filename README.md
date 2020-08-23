# PiVPN in Docker Container

Setting up an VPN server is easy, but we can make it even easier and you can do it within 1 min. All the prerequisite is just the docker which has been compatible with the Raspberry Pi for a while. If you don't have the docker installed on your little machine, go and check it out [here](https://www.raspberrypi.org/blog/docker-comes-to-raspberry-pi/).


## Build

[![Build Status](https://travis-ci.org/ljishen/pivpn-docker.svg?branch=master)](https://travis-ci.org/ljishen/pivpn-docker)


## Docker Images

[![](https://images.microbadger.com/badges/version/ljishen/pivpn:amd64.svg)](https://microbadger.com/images/ljishen/pivpn:amd64 "Get your own version badge on microbadger.com")
[![](https://images.microbadger.com/badges/image/ljishen/pivpn:amd64.svg)](https://microbadger.com/images/ljishen/pivpn:amd64 "Get your own image badge on microbadger.com")

[![](https://images.microbadger.com/badges/version/ljishen/pivpn:armv7hf.svg)](https://microbadger.com/images/ljishen/pivpn:armv7hf "Get your own version badge on microbadger.com")
[![](https://images.microbadger.com/badges/image/ljishen/pivpn:armv7hf.svg)](https://microbadger.com/images/ljishen/pivpn:armv7hf "Get your own image badge on microbadger.com")


## Supported Architectures

- x86_64/amd64
- armv7hf (Raspberry Pi 2 and 3)

<hr>

## Server-side Usage

### Using Docker

How to launch PiVPN on the PiVPN server machine using ```docker```:
```bash
docker run -ti --rm \
    --privileged \
	--net host \
    -p 1194:1194/udp \
    -v /home/docker/pivpn/ovpns:/home/pivpn/ovpns \
    -v /home/docker/pivpn/openvpn:/etc/openvpn \
    ljishen/pivpn
```
Wait until you see `PiVPN Service Started`

### Using Docker-Compose

How to launch PiVPN on the PiVPN server machine using ```docker-compose```, using the included ```docker-compose.yaml```:
```bash
docker-compose -f **<repo>**/docker-compose.yaml up -d
```

### Container First Run

On first launch, the certificates and DH parameters are generated.  Without a volume mounted at `/etc/openvpn`, the certificates and DH parameters will be generated **EVERY** time the container is started!

<hr>

## Client-side Usage

1. Copy the client ovpn profile under `"$HOME"/ovpns` to the machine/device from where you want to connect to the PiVPN server. The name of the client profile is `client.ovpn` by default.

2. Install the `OpenVPN` application on the client. On Debian OS, it would be as easy as
   ```bash
   sudo apt-get install openvpn
   ```

   Then you can start the VPN client using
   ```bash
   sudo openvpn --auth-nocache --config client.ovpn
   ```

## Credit

- [PiVPN](https://github.com/pivpn/pivpn)


## Miscellaneous

#### Commands to Create the Docker Image Manifest

```bash
docker manifest create ljishen/pivpn ljishen/pivpn:amd64 ljishen/pivpn:armv7hf
docker manifest annotate ljishen/pivpn ljishen/pivpn:armv7hf --os linux --arch arm --variant v7
docker manifest annotate ljishen/pivpn ljishen/pivpn:amd64 --os linux --arch amd64

# purge the local manifest after push so that I can
# upgrade the manifest by creating a new one next time.
# https://github.com/docker/for-win/issues/1770
docker manifest push --purge ljishen/pivpn
```
