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


## Usage

1. Launch PiVPN on a machine, which would be the PiVPN server.
   ```bash
   docker run -ti --rm \
        --privileged \
        -p 443:443/udp \
        -v "$HOME"/ovpns:/home/pivpn/ovpns \
        ljishen/pivpn
   ```

2. Copy the client ovpn profile under `"$HOME"/ovpns` to the machine/device from where you want to connect to the PiVPN server. The name of the client profile is `client.ovpn` by default.

3. Install the `OpenVPN` application on the client. On Debian OS, it would be as easy as
   ```bash
   sudo apt-get install openvpn
   ```

   Then you can start the VPN client using
   ```bash
   sudo openvpn --auth-nocache --config client.ovpn
   ```

   The default Private Key Password is `vpnpasswd` and you can change it in the configuration file `setupVars.conf`.

4. In case you have any connection problems, try to modify the variables in file `setupVars.conf` before restarting the PiVPN server using the same command from `step 1`. You can also create an issue and let me know if I can help you.


## Credit

- [PiVPN](https://github.com/pivpn/pivpn)
