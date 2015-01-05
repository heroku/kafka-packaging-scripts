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
git merge $BRANCH

git-buildpackage -us -uc --git-debian-branch=debian-$VERSION --git-upstream-tree=$BRANCH --git-verbose
popd

# Debian packaging dumps packages one level up. We try to save all the build
# output, including orig tarballs
cp kafka-rest_*.build kafka-rest_*.changes kafka-rest_*.tar.gz kafka-rest_*.dsc  kafka-rest_*.deb /vagrant/output/
