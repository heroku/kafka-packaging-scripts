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
cd common

git checkout -b rpm-$VERSION origin/rpm
git merge $BRANCH
make distclean
make rpm
cp *.rpm /vagrant/output/
