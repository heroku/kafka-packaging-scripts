#!/bin/bash

set -e
set -x

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/common
git clone /vagrant/repos/common.git
pushd common

git checkout -b debian-$VERSION origin/debian
git merge $BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=$BRANCH --git-verbose
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs
cp confluent-common_*.build confluent-common_*.changes confluent-common_*.tar.gz confluent-common_*.dsc  confluent-common_*.deb /vagrant/output/
