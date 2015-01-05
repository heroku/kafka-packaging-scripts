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
cp rest-utils_*.build rest-utils_*.changes rest-utils_*.tar.gz rest-utils_*.dsc  rest-utils_*.deb /vagrant/output/
