#!/bin/bash

set -e
set -x

# Get the VM ready to do the build. This is specifically separated out from the
# build process so we don't have to run it every time we want to build. This
# should really only handle system updates and system-level build dependencies.

sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get install -y make curl git zip unzip patch java7-jdk maven \
    git-buildpackage javahelper gnupg


# These should not be leaking out anywhere with the build output so the values
# don't matter, but we need to specify them or git commands will fail. These are
# setup for root because builds run as root in order to be able to setup file
# permissions properly.
sudo -u vagrant -i git config --global user.email "contact@confluent.io"
sudo -u vagrant -i git config --global user.name "Confluent, Inc."
