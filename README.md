# PiVPN in Docker Container

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
