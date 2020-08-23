# VERSION 1.0

FROM phusion/baseimage:master

# Silence error:
ENV DEBIAN_FRONTEND=noninteractive

# Set as env so that it can also be used in the run script during the execution.
ENV install_user=pivpn

# Make sure the IN_DOCKER variable is cleared:
ENV IN_DOCKER=

# Pulled PiVPN Repository location
ARG pivpnFilesDir=/etc/.pivpn

# PiVPN Installer location
ARG INSTALLER=/etc/.pivpn/auto_install/install.sh

# PiVPN setupVars.conf location
ARG setupVars=/etc/pivpn/setupVars.conf

#=============================================================================================================================
# Install the prerequisites, then pull the PiVPN repo.  Also create a "cls" clone of the "clear" command...
#=============================================================================================================================
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 git dhcpcd5 nano \
	&& git clone https://github.com/pivpn/pivpn.git "${pivpnFilesDir}" \
	&& ln -sf /usr/bin/clear /usr/local/bin/cls

#=============================================================================================================================
# Due to an unresolved bug in the Go archive/tar package’s handling of sparse files, attempting to create a user with
# a sufficiently large UID inside a Docker container can lead to disk exhaustion as /var/log/faillog in the
# container layer is filled with NUL (\0) characters.   Passing the --no-log-init flag to useradd works around
# this issue.
# :: See https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
#=============================================================================================================================
RUN useradd --no-log-init -rm -s /bin/bash "${install_user}"

#=============================================================================================================================
# Copy setupVars.conf and force PiVPN port to be 1194.  The port can be overridden using docker's port mapping switches.
#=============================================================================================================================
COPY setupVars.conf "${setupVars}"
RUN sed -i "s|pivpnPORT=.*|pivpnPORT=1194|g" "${setupVars}"

#=============================================================================================================================
# What each line does:
#  1. Remove "debconf-apt-progress" usage because command is not responsive during the image build
#  2. Remove the command line "systemctl start openvpn.service" since the systemctl is not supported during the image build
#  3. Remove the calling of function "setStaticIPv4"
#  4. Remove the calling of function "RestartServices"
#  5. Remove the calling of function "confLogging"
#  6. Modify main function call to be skipped if we are running a docker container
#  7. Skip creating server certificates and DH parameters if we are not running a docker container
#  8. Skip configuring the network if we are not running a docker container
#  9. Rename "confOpenVPN" function to "generateServerName"
# 10. Split OpenVPN backup code from new "generateServerName" function into "backupOpenVPN" function
# 11. Split code pulling EasyRSA from "backupOpenVPN" function into "confOpenVPN" function
# 12. Split code creating server certificates and DH params from "confOpenVPN" function into "GenerateOpenVPN" function
# 13. Split code writing "server.conf" from "GenerateOpenVPN" function into "createServerConf" function
# 14. Hide output of "getent passwd openvpn" command
#=============================================================================================================================
#RUN curl -fsSL0 https://install.pivpn.io -o "${INSTALLER}"
RUN sed -i 's/debconf-apt-progress --//g' "${INSTALLER}" \
	&& sed -i '/systemctl start/d' "${INSTALLER}" \
	&& sed -i '/setStaticIPv4 #/d' "${INSTALLER}" \
	&& sed -i "/restartServices$/d" "${INSTALLER}" \
	&& sed -i "/confLogging$/d" "${INSTALLER}" \
	&& sed -i "s|main \"\$@\"|if [[ -z \"\$IN_DOCKER\" ]]; then\n\tmain \"\$@\"\nfi|g" "${INSTALLER}" \
	&& sed -i 's|confOVPN$|[[ ! -z "\$IN_DOCKER" ]] \&\& confOVPN|g' "${INSTALLER}" \
	&& sed -i 's|confNetwork$|[[ ! -z "\$IN_DOCKER" ]] \&\& confNetwork|g' "${INSTALLER}" \
	&& sed -i "s|confOpenVPN(){|generateServerName(){|" "${INSTALLER}" \
	&& sed -i "s|\t# Backup the openvpn folder|}\n\nbackupOpenVPN(){\n\t# Backup the openvpn folder|" "${INSTALLER}" \
	&& sed -i "s|\tif \[ -f /etc/openvpn/server.conf \]; then|}\n\nconfOpenVPN(){\n\tif [ -f /etc/openvpn/server.conf ]; then|" "${INSTALLER}" \
	&& sed -i 's|cd /etc/openvpn/easy-rsa|$SUDO mv /etc/openvpn /etc/openvpn.orig\n}\n\nGenerateOpenVPN() {\n\t$SUDO cp -R /etc/openvpn.orig/* /etc/openvpn/\n\tcd /etc/openvpn/easy-rsa|' "${INSTALLER}" \
	&& sed -i "s|  if ! getent passwd openvpn; then|}\n\ncreateServerConf(){\n\t  if ! getent passwd openvpn; then|" "${INSTALLER}" \
	&& sed -i "s|getent passwd openvpn|getent passwd openvpn \>\& /dev/null|" "${INSTALLER}"

#=============================================================================================================================
# Run the installer, clean up leftover archive files, then clean up apt lists and files in "/var/tmp" and "/tmp":
#=============================================================================================================================
RUN "${INSTALLER}" --unattended "${setupVars}" --reconfigure \
	&& mv /tmp/setupVars.conf "${setupVars}" \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

EXPOSE 1194

WORKDIR /home/"${install_user}"
COPY run .
CMD ["./run"]
