# VERSION 1.0

FROM phusion/baseimage:0.10.0
MAINTAINER Jianshen Liu <jliu120@ucsc.edu>

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2

ARG pivpnUser=pivpn

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

ARG INSTALLER=/tmp/install.sh

# 1. Remove the use of command "debconf-apt-progress" because
#    the exit code is not 0 even on success.
# 2. Function spinner does not work during image build, so
#    remove the spinner call after the "git clone".
RUN curl -fsSL0 https://install.pivpn.io -o "${INSTALLER}" \
    && sed -i 's/debconf-apt-progress --//g' "${INSTALLER}" \
    && sed -i 's/\(git clone.*\) *>.*/\1/g' "${INSTALLER}" \
    && chmod +x "${INSTALLER}" \
    && "${INSTALLER}" --unattended


RUN sed -i 's/set -e/set -ex/g' "/etc/.pivpn/auto_install/install.sh"

# Clean Up
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /home/"${pivpnUser}"
COPY up .
CMD ["up"]
