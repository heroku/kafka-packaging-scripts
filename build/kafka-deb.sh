#!/bin/bash

set -e
set -x

# Get a fresh copy of the repository. Unlike most of our other packaging
# scripts, this one requires two repositories since the packaging scripts are
# not kept with the open source code.
mkdir -p /tmp/confluent
cd /tmp/confluent

# Debian requires that we generate all the binary packages from one source
# package and Kafka needs one package per Scala version, so this build script
# looks a bit different than others. The control file specifies the versions of
# packages we will generate so we need to generate one including the versions we
# need.

rm -rf /tmp/confluent/kafka-packaging
git clone /vagrant/repos/kafka-packaging.git
pushd kafka-packaging
git fetch --tags /vagrant/repos/kafka.git

git checkout -b debian-$VERSION origin/debian
make -f debian/Makefile debian-control
git merge --no-edit -m "deb-$VERSION" $VERSION

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tag=$VERSION --git-verbose
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f confluent-kafka_*.changes`
fi
cp confluent-kafka_*.build confluent-kafka_*.changes confluent-kafka_*.tar.gz confluent-kafka_*.dsc confluent-kafka-*.deb /vagrant/output/
