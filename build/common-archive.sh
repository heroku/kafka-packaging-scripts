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

git checkout -b archive-$VERSION origin/archive
git merge $BRANCH
make distclean
make archive
cp *.zip *.tar.gz /vagrant/output/
