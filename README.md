![PiVPN](https://blog.virgulilla.com/2018/luisddm-pivpn/pivpn_logo.png)

# OpenVPN-based PiVPN in a Docker Container!

Setting up an VPN server is easy, but we can make it even easier and you can do it within 1 min. All the prerequisite is just the docker which has been compatible with the Raspberry Pi for a while. If you don't have the docker installed on your little machine, go and check it out [here](https://www.raspberrypi.org/blog/docker-comes-to-raspberry-pi/).

## Supported Architectures

- x86_64/amd64
- armv7hf (Raspberry Pi 2 and 3)

## Server-side Usage

### Using Docker

How to launch PiVPN on the PiVPN server machine using ```docker```:
```bash
docker run -ti --rm \
    --privileged \
    --net host \
    --name pivpn \
    -v /home/docker/pivpn/ovpns:/home/pivpn/ovpns \
    -v /home/docker/pivpn/openvpn-data:/etc/openvpn \
    xptsp/pivpn
```
Wait until you see `PiVPN Service Started`

### Using Docker-Compose

Basic `docker-compose.yaml` file to use with **docker-compose**:
```bash
version: '2.1'
services:
  pivpn:
    container_name: pivpn
    image: xptsp/pivpn
    privileged: true
    network_mode: "host"
    volumes:
      - /home/docker/pivpn/ovpns:/home/pivpn/ovpns
      - /home/docker/pivpn/openvpn-data:/etc/openvpn
```

### Available Environmental Variables

- **IPv4dev** - Specifies the host networking adapter to use.  Default: autodetected
- **pivpnHOST** - Specifies the domain name or IP address.  Default: IP address autodetected
- **pivpnSEARCHDOMAIN** - Specifies the name of a custom search domain server.  Default: none
- **pivpnPORT** - Specifies the network port that your PiVPN uses.  Default: `1194`
- **pivpnPROTO** - Specifies the network protocol to use (udp/tcp).  Default: `udp`
- **pivpnDNS1** - Specifies 1st Domain Name Server to use for your PiVPN.  Default: `8.8.8.8`
- **pivpnDNS2** - Specifies 2nd Domain Name Server to use for your PiVPN, can be `none`.  Default: `8.8.4.4`
- **pivpnTWO_POINT_FOUR** - Specifies whether to support OpenVPN 2.4 (0/1).  Default: `0` (no)
- **pivpnENCRYPT** - Specifies the number of bits your DH-parameters are generated with.  Default: `2048`
- **pivpnDH_PREDEFINED** - Use predefined DH parameters included with PiVPN repo (0/1).  Default: `0` (no)
- **pivpnDH_DOWNLOAD** - Downloads DH parameters from [2ton.com.au](https://2ton.com.au) (0/1).  Default: `0` (no)
- **pivpnDEV** - The name of the VPN network adapter.  Default: `pivpn`
- **pivpnNET** - The IP range that this adapter will use.  Default: `10.8.0.0`
- **pivpnWEB_PORT** - Specifies the port the container management UI to use, `0` to disable.  Default: `0`
- **pivpnWEB_MGMT** - Specifies the OpenVPN management port to use.  Default: **pivpnWEB_PORT** plus 1

When linking a PiHole to this container, you should include environment variables `pivpnDNS1=10.8.0.1` and `pivpnDNS2=none` to this container.  This should link them correctly, at least from PiVPN's side.

### Required Volumes to Mount

- You **MUST** mount a volume to `/etc/openvpn` in order to store the OpenVPN data.  Failure to do so will result in the server certificates and DH parameters being generated with **EVERY** launch of the container, instead of just the first launch of the container.

- You **MUST** mount a directory to `/home/pivpn/ovpns` in order to store the generated client certificates.  If you do not mount a volume here, generated certificates will be lost upon restarting the container!

- If you have multiple network interfaces (ie: an ethernet and a wireless interface), you **MUST** specify the **IPv4dev** variable!  Otherwise, the container will not start because there is more than one network interface that could be used and installer isn't smart enough to make that decision by itself.

### Container First Run

On first launch, the server certificates and DH parameters are generated.  The default encryption is 2048-bit, which (according to [pivpn.net](https://www.pivpn.io)) will take about 40 minutes to generate on a Model B+, and several hours if you choose a larger size.

## Managing Client Certificates

### Creating a Client Certificate
`docker exec -it pivpn pivpn add`

 You will be prompted to enter a name for your client. Pick anything you like and hit 'enter'. You will be asked to enter a pass phrase for the client key; make sure it's one you'll remember. The script will assemble the client .ovpn file and place it in the volume mounted on the directory `/home/pivpn/ovpns` within your home directory.

If you need to create a client certificate that is not password protected (IE for use on a router), then you can use the 'pivpn add nopass' option to generate that.

### Revoking a Client Certificate
`docker exec -it pivpn pivpn revoke`

Asks you for the name of the client to revoke. Once you revoke a client, it will no longer allow you to use the given client certificate (ovpn config) to connect. This is useful for many reasons but some ex: You have a profile on a mobile phone and it was lost or stolen. Revoke its cert and generate a new one for your new phone. Or even if you suspect that a cert may have been compromised in any way, just revoke it and generate a new one.

### Listing Client Certificates
`docker exec -it pivpn pivpn list`

If you add more than a few clients, this gives you a nice list of their names and whether their certificate is still valid or has been revoked. Great way to keep track of what you did with 'pivpn add' and 'pivpn revoke'.

## Issues
If you have any issues with this docker container, please open an issue over in the [GitHub repository](https://github.com/xptsp/pivpn-docker/issues) and I'll try to address the issue as soon as I am able.  Thanks for helping improve this docker container!

## Version History

### v2 - Unreleased
- Added check for requirement of running container in privileged mode.
- Added check for requirement of volume mount on "/etc/openvpn".
- Added check for requirement of volume mount on "/home/pivpn/ovpns".
- Fixed multiple issues of creating duplicated function names within Dockerfile.
- Added code to allow certain environment variables to override defaults in container.
- Moved log file to `/etc/openvpn/pivpn-docker.log`.
- Cleared out `pivpnHOST` and `IPv4dev` variables from "/tmp/setupVars.conf".
- Added option to download a DH parameter file from [2ton.com.au](https://2ton.com.au) ([PiVPN commit 548492832d1ae1337c3e22fd0b2b487ca1f06cb0](https://github.com/pivpn/pivpn/tree/548492832d1ae1337c3e22fd0b2b487ca1f06cb0))
- Added code to `run` script to launch `lighttpd` for an unfinished web interface.
- Added code for OpenVPN management port for the VPN tunnel when web interface launches.

### v1 - August 23rd, 2020
- Refactored [pivpn-docker GitHub repo](https://github.com/ljishen/pivpn-docker) to run the latest PiVPN install script.
- Merged both `Dockerfile`s into a single `Dockerfile` for easier container builds.
- Added documentation about volume mount points, as well as container first run notes.

## Credits

- [PiVPN](https://github.com/pivpn/pivpn)
- Based on the [pivpn-docker GitHub repo](https://github.com/ljishen/pivpn-docker)
- [Ample Bootstrap Admin Lite](https://www.wrappixel.com/templates/ample-admin-lite/?ref=17)
