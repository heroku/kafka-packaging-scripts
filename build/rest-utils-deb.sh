#!/bin/bash

set -e
set -x

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/rest-utils
git clone /vagrant/repos/rest-utils.git
pushd rest-utils

git checkout -b debian-$VERSION origin/debian
git merge $BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=$BRANCH --git-verbose
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs
cp confluent-rest-utils_*.build confluent-rest-utils_*.changes confluent-rest-utils_*.tar.gz confluent-rest-utils_*.dsc  confluent-rest-utils_*.deb /vagrant/output/
