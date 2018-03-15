# VERSION 1.0

FROM phusion/baseimage:0.10.0
MAINTAINER Jianshen Liu <jliu120@ucsc.edu>

# Silence error:
# dpkg-preconfigure: unable to re-open stdin:
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        iproute2 \
        git

ARG pivpnFilesDir=/etc/.pivpn
RUN git clone https://github.com/pivpn/pivpn.git "${pivpnFilesDir}" \
        && git -C "${pivpnFilesDir}" checkout aa625b98ffb00d71ef40ade3ac6b69cce40b7a8e

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

# Command "debconf-apt-progress" is not responsive during the image build.
RUN curl -fsSL0 https://install.pivpn.io -o "${INSTALLER}" \
    && sed -i 's/debconf-apt-progress --//g' "${INSTALLER}" \
    && chmod +x "${INSTALLER}" \
#    && sed -i 's/set -e/set -eux/g' "${INSTALLER}" \
    && "${INSTALLER}" --unattended --reconfigure

# Do NOT clean the /tmp/* since we are going to use the content
# later in the run script.
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/tmp/*

WORKDIR /home/"${pivpnUser}"
COPY run .
CMD ["./run", "|", "tee", "-a", "${instalLogLoc}"]
