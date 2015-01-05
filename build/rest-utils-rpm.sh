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
cd rest-utils

git checkout -b rpm-$VERSION origin/rpm
git merge $BRANCH
make rpm
cp *.rpm /vagrant/output/
