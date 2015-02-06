#!/bin/bash

set -e
set -x

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/kafka-rest
git clone /vagrant/repos/kafka-rest.git
pushd kafka-rest

git checkout -b debian-$VERSION origin/debian
git merge --no-edit $BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=$BRANCH --git-verbose
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs. Signing requires sudo --login because we're
# actually executing this script with sudo to get root permissions, but it
# retains the env vars from the vagrant ssh user.
if [ "x$SIGN" == "xyes" ]; then
    sudo --login debsign `readlink -f confluent-kafka-rest_*.changes`
fi
cp confluent-kafka-rest_*.build confluent-kafka-rest_*.changes confluent-kafka-rest_*.tar.gz confluent-kafka-rest_*.dsc  confluent-kafka-rest_*.deb /vagrant/output/
rm -rf /tmp/confluent
