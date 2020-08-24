# VERSION 1.0

FROM phusion/baseimage:master

# Silence error:
ENV DEBIAN_FRONTEND=noninteractive

# Set as env so that it can also be used in the run script during the execution.
ENV install_user=pivpn

# Make sure the IN_DOCKER variable is cleared:
ENV IN_DOCKER=

# Pulled PiVPN Repository location
ARG pivpnFilesDir=/usr/local/src/pivpn

# PiVPN installer locations
ARG ORIGINAL=${pivpnFilesDir}/auto_install/install.sh
ARG MODDED=/tmp/pivpn_install_modded.sh

# PiVPN setupVars.conf location
ARG setupVars=/etc/pivpn/setupVars.conf

#=============================================================================================================================
# Install the prerequisites, then pull the PiVPN repo.  Also create a "cls" clone of the "clear" command...
#=============================================================================================================================
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 git dhcpcd5 nano \
		iptables-persistent bsdmainutils net-tools whiptail dnsutils grep wget tar net-tools openvpn expect curl sudo grepcidr \
	&& git clone https://github.com/pivpn/pivpn.git "${pivpnFilesDir}" \
	&& ln -sf /usr/bin/clear /usr/local/bin/cls

#=============================================================================================================================
# Due to an unresolved bug in the Go archive/tar package’s handling of sparse files, attempting to create a user with
# a sufficiently large UID inside a Docker container can lead to disk exhaustion as /var/log/faillog in the
# container layer is filled with NUL (\0) characters.   Passing the --no-log-init flag to useradd works around
# this issue.
# :: See https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
#=============================================================================================================================
RUN useradd --no-log-init -m -s /bin/bash "${install_user}"

#=============================================================================================================================
# Copy setupVars.conf and force PiVPN port to be 1194.  The port can be overridden using docker's port mapping switches.
#=============================================================================================================================
COPY setupVars.conf "${setupVars}"
RUN sed -i "s|pivpnPORT=.*|pivpnPORT=1194|g" "${setupVars}"

#=============================================================================================================================
# What each line does (in order):
#  1. Copies the original installer to modified installer location
#  2. Remove "debconf-apt-progress" usage because command is not responsive during the image build
#  3. Remove the command line "systemctl start openvpn.service" since the systemctl is not supported during the image build
#  4. Remove the calling of function "setStaticIPv4"
#  5. Remove the calling of function "RestartServices"
#  6. Remove the calling of function "confLogging"
#  7. Change calling of function "confOVPN" to function "createOVPNuser"
#  8. Remove the calling of function "confNetwork"
#  9. Rename "confOpenVPN" function to "generateServerName"
# 10. Split OpenVPN backup code from new "generateServerName" function into "backupOpenVPN" function
# 11. Split code pulling EasyRSA from "backupOpenVPN" function into "confOpenVPN" function
# 12. Split code creating server certificates and DH params from "confOpenVPN" function into "GenerateOpenVPN" function
# 13. Split user creation code from "GenerateOpenVPN" function into "createOVPNuser" function
# 14. Split writing "server.conf" code from "createOVPNuser" function into "createServerConf" function.
# 15. Hide output of "getent passwd openvpn" command
#=============================================================================================================================
RUN cp "${ORIGINAL}" "${MODDED}" \
	&& sed -i 's/debconf-apt-progress --//g' "${MODDED}" \
	&& sed -i '/systemctl start/d' "${MODDED}" \
	&& sed -i '/setStaticIPv4 #/d' "${MODDED}" \
	&& sed -i "/restartServices$/d" "${MODDED}" \
	&& sed -i "/confLogging$/d" "${MODDED}" \
	&& sed -i 's|confOVPN$|createOVPNuser|g' "${MODDED}" \
	&& sed -i '/confNetwork$/d' "${MODDED}" \
	&& sed -i "s|confOpenVPN(){|generateServerName(){|" "${MODDED}" \
	&& sed -i "s|# Backup the openvpn folder|echo \"SERVER_NAME=\$SERVER_NAME\" >> \"/etc/openvpn/.server_name\"\n}\n\nbackupOpenVPN(){\n\t# Backup the openvpn folder|" "${MODDED}" \
	&& sed -i "s|\tif \[ -f /etc/openvpn/server.conf \]; then|}\n\nconfOpenVPN(){\n\tif [ -f /etc/openvpn/server.conf ]; then|" "${MODDED}" \
	&& sed -i 's|cd /etc/openvpn/easy-rsa|$SUDO mv /etc/openvpn /etc/openvpn.orig\n}\n\nGenerateOpenVPN() {\n\t$SUDO cp -R /etc/openvpn.orig/* /etc/openvpn/\n\tcd /etc/openvpn/easy-rsa|' "${MODDED}" \
	&& sed -i "s|  if ! getent passwd openvpn; then|}\n\ncreateOVPNuser(){\n  if ! getent passwd openvpn; then|" "${MODDED}" \
	&& sed -i "s|  \${SUDOE} chown \"\$debianOvpnUserGroup\" /etc/openvpn/crl.pem|}\n\ncreateServerConf(){\n  \${SUDOE} chown \"\$debianOvpnUserGroup\" /etc/openvpn/crl.pem|" "${MODDED}" \
	&& sed -i "s|getent passwd openvpn|getent passwd openvpn \>\& /dev/null|" "${MODDED}"

#=============================================================================================================================
# What each line does (in order):
#  1. Run the modified installer
#  2. Clean up leftover archive files
#  3. Removes any files in the "/var/lib/apt/lists" and "/var/tmp" folders
#  4. Removes the calling of function "main"
# NOTE: It's tempting to also remove files from "/tmp", but our "run" script requires the modded install located there!
#=============================================================================================================================
RUN "${MODDED}" --unattended "${setupVars}" --reconfigure \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /var/tmp/* \
	&& sed -i "/main \"\$@\"/d" "${MODDED}"

#=============================================================================================================================
# Everything else required for this Docker image:
#=============================================================================================================================
EXPOSE 1194
WORKDIR /home/"${install_user}"
COPY run .
CMD ["./run"]
