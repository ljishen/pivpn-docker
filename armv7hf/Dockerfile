# VERSION 1.0

FROM resin/raspberrypi3-debian:stretch
MAINTAINER Jianshen Liu <jliu120@ucsc.edu>

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        dhcpcd5

ARG pivpnFilesDir=/etc/.pivpn
# Should check all the logics before upgrading the version
RUN git clone https://github.com/pivpn/pivpn.git "${pivpnFilesDir}" \
        && git -C "${pivpnFilesDir}" checkout 548492832d1ae1337c3e22fd0b2b487ca1f06cb0

# Set as env so that it can also be used in
# the run script during the execution.
ENV pivpnUser=pivpn

# Due to an unresolved bug in the Go archive/tar package’s
# handling of sparse files, attempting to create a user with
# a sufficiently large UID inside a Docker container can
# lead to disk exhaustion as /var/log/faillog in the
# container layer is filled with NUL (\0) characters.
# Passing the --no-log-init flag to useradd works around
# this issue.
# See https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
RUN useradd --no-log-init -rm -s /bin/bash "${pivpnUser}"

COPY setupVars.conf /etc/pivpn/

ARG PIVPN_TEST=false
ARG SUDO=
ARG SUDOE=
ARG INSTALLER=/tmp/install.sh

# Customize the content to be appended to /etc/dhcpcd.conf so that
# we can replace the placeholders later in the run script.
RUN printf '\n\
interface #pivpnInterface#\n\
static ip_address=#IPv4addr#\n\
static routers=#IPv4gw#\n\
static domain_name_servers=#IPv4dns#' >> /etc/dhcpcd.conf

# 1. Command "debconf-apt-progress" is not responsive during the image build.
# 2. Remove the command line "systemctl start openvpn.service" since the
#    systemctl is not supported during the image build.
# 3. Remove the calling of function setStaticIPv4 so that we can customize
#    the content to be appended to /etc/dhcpcd.conf
RUN curl -fsSL0 https://install.pivpn.io -o "${INSTALLER}" \
    && sed -i 's/debconf-apt-progress --//g' "${INSTALLER}" \
    && sed -i '/systemctl start/d' "${INSTALLER}" \
    && sed -i '/setStaticIPv4 #/d' "${INSTALLER}" \
    && chmod +x "${INSTALLER}" \
#    && sed -i 's/set -e/set -eux/g' "${INSTALLER}" \
    && "${INSTALLER}" --unattended --reconfigure

# Do NOT clean the /tmp/* since we are going to use the content
# later in the run script.
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/tmp/*

WORKDIR /home/"${pivpnUser}"
COPY run .
CMD ["./run"]
