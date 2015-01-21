#!/bin/bash

set -e
set -x

# Get the VM ready to do the build. This is specifically separated out from the
# build process so we don't have to run it every time we want to build. This
# should really only handle system updates and system-level build dependencies.

apt-get -y update
apt-get install -y software-properties-common python-software-properties
add-apt-repository -y ppa:webupd8team/java
apt-get -y update
sudo apt-get upgrade -y

/bin/echo debconf shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections

sudo apt-get install -y make curl git zip unzip patch \
    oracle-java6-installer oracle-java6-set-default maven \
    git-buildpackage javahelper


# These should not be leaking out anywhere with the build output so the values
# don't matter, but we need to specify them or git commands will fail. These are
# setup for root because builds run as root in order to be able to setup file
# permissions properly.
sudo -u vagrant -i git config --global user.email "contact@confluent.io"
sudo -u vagrant -i git config --global user.name "Confluent, Inc."
