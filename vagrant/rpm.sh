#!/bin/bash

set -e
set -x

# Get the VM ready to do the build. This is specifically separated out from the
# build process so we don't have to run it every time we want to build. This
# should really only handle system updates and system-level build dependencies.

yum -y update

yum -y install git java-1.7.0-openjdk-devel maven rpm-build


# These should not be leaking out anywhere with the build output so the values
# don't matter, but we need to specify them or git commands will fail. These are
# setup for root because builds run as root in order to be able to setup file
# permissions properly.
git config --global user.email "contact@confluent.io"
git config --global user.name "Confluent, Inc."
