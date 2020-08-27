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
# Install the PiVPN prerequisites, then pull the PiVPN repo.  Also create a "cls" clone of the "clear" command...
#=============================================================================================================================
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 git dhcpcd5 nano telnet lighttpd ca-certificates \
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
RUN useradd --no-log-init -m -s /bin/bash "${install_user}" \
	&& sed -i "s|/root|/home/pivpn|g" /etc/passwd

#=============================================================================================================================
# Copy setupVars.conf to the PiVPN data location.
#=============================================================================================================================
COPY setupVars.conf "${setupVars}"

#=============================================================================================================================
# Main feature: PiVPN installation script changes!
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
# 16. Added code to allow downloading DH parameters from "2ton.com.au" (PiVPN commit 548492832d1ae1337c3e22fd0b2b487ca1f06cb0)
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
	&& sed -i "s|# Backup the openvpn folder|echo \"SERVER_NAME=\$SERVER_NAME\" >> \"/etc/openvpn/.server_name\"\n}\n\nbackupOpenVPN(){\n\t# Backup  the openvpn folder|" "${MODDED}" \
	&& sed -i "s|\tif \[ -f /etc/openvpn/server.conf \]; then|}\n\nconfOpenVPN(){\n\tif  [ -f /etc/openvpn/server.conf ]; then|" "${MODDED}" \
	&& sed -i 's|cd /etc/openvpn/easy-rsa|$SUDO mv /etc/openvpn /etc/openvpn.orig\n}\n\nGenerateOpenVPN() {\n\t$SUDO cp -R /etc/openvpn.orig/* /etc/openvpn/\n\tcd  /etc/openvpn/easy-rsa|' "${MODDED}" \
	&& sed -i "s|  if ! getent passwd openvpn; then|}\n\ncreateOVPNuser(){\n  if ! getent  passwd openvpn; then|" "${MODDED}" \
	&& sed -i "s|  \${SUDOE} chown \"\$debianOvpnUserGroup\" /etc/openvpn/crl.pem|}\n\ncreateServerConf(){\n  \${SUDOE} chown \$debianOvpnUserGroup /etc/openvpn/crl.pem|" "${MODDED}" \
	&& sed -i "s|getent passwd openvpn|getent passwd openvpn \>\& /dev/null|" "${MODDED}" \
	&& sed -i "s|if \[ \"\${USE_PREDEFINED_DH_PARAM}\" -eq 1 \]; then|if \[ \"\${DOWNLOAD_DH_PARAM}\" -eq 1 \]; then\n\t\t\t\${SUDOE} curl \"https://2ton.com.au/getprimes/random/dhparam/\${pivpnENCRYPT}\" -o pki/dh\"\${pivpnENCRYPT}\".pem\n\t\telif [ \"\${USE_PREDEFINED_DH_PARAM}\" -eq 1 ]; then|" ${MODDED}

#=============================================================================================================================
# What each line does (in order):
#  1. Run the modified installer
#  2. Removes the calling of function "main"
#=============================================================================================================================
RUN bash "${MODDED}" --unattended "${setupVars}" --reconfigure \
	&& sed -i "/main \"\$@\"/d" "${MODDED}"

#=============================================================================================================================
# What each line does (in order):
#  1. Removes the "pivpnHOST" line from "/tmp/setupVars.conf".
#  2. Removes the "IPv4dev" line from "/tmp/setupVars.conf".
#  3. Adds "pivpnUSE_PREDEFINED_DH_PARAM" variable to "/tmp/setupVars.conf".
#  4. Adds "pivpnDOWNLOAD_DH_PARAM" variable to "/tmp/setupVars.conf".
#  5. Adds "pivpnTWO_POINT_FOUR" variable to "/tmp/setupVars.conf".
#  6. Change the PiVPN network interface name to "pivpn".
#=============================================================================================================================
RUN sed -i "/^pivpnHOST=/d" /tmp/setupVars.conf \
	&& sed -i "/^IPv4dev=/d" /tmp/setupVars.conf \
	&& echo "pivpnDH_DOWNLOAD=0" >> /tmp/setupVars.conf \
	&& echo "pivpnDH_PREDEFINED=0" >> /tmp/setupVars.conf \
	&& echo "pivpnTWO_POINT_FOUR=0" >> /tmp/setupVars.conf \
	&& sed -i "s|^pivpnDEV=.*|pivpnDEV=pivpn|" /tmp/setupVars.conf

#=============================================================================================================================
# What each line does (in order) to set up the web interface:
#  1. Copies the "html" folder from the repo to "/var/www/html".
#  2. Remove original lighttpd html file.
#  3. Add the "mod_cgi" and "mod_auth" to "/etc/lighttpd/lighttpd.conf".
#  4. Add a cgi handler for the ".sh" extension to "/etc/lighttpd/lighttpd.conf".
#  5. Add the ability to use files with ".sh" extension properly to "/etc/lighttpd/lighttpd.conf".
#  6. Add the contents of "/var/www/html/lighttpd.inc" to "/etc/lighttpd/lighttpd.conf".
#  7. Remove "/var/www/html/lighttpd.inc".
#  8. Change ownership of the "/var/www/html" to "www-data:www-data".
#  9. Add default web password to the "/tmp/setupVars.conf".
# 10. Add default web port to the "/tmp/setupVars.conf".
#=============================================================================================================================
COPY html /var/www/html/
RUN rm /var/www/html/index.lighttpd.html \
	&& sed -i "s|\"mod_redirect\"|\"mod_redirect\",\"mod_cgi\",\"mod_auth\"|" /etc/lighttpd/lighttpd.conf \
	&& sed -i "/server.document-root/i \cgi.assign = \( \".sh\" => \"/bin/bash\" \)" /etc/lighttpd/lighttpd.conf \
	&& sed -i "s|index.php|index.sh\", \"index.php|" /etc/lighttpd/lighttpd.conf \
	&& cat /var/www/html/lighttpd.inc >> /etc/lighttpd/lighttpd.conf \
	&& rm /var/www/html/lighttpd.inc \
	&& chown -R www-data:www-data -R /var/www/html/ \
	&& echo "pivpnWEB_PASS=password" >> /tmp/setupVars.conf \
	&& echo "pivpnWEB_PORT=0" >> /tmp/setupVars.conf

#=============================================================================================================================
# Everything else required for this Docker image:
#=============================================================================================================================
WORKDIR /home/"${install_user}"
COPY run .
CMD /bin/bash ./run
