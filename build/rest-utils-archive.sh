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

git checkout -b archive-$VERSION origin/archive
git merge $BRANCH
make archive
cp *.zip *.tar.gz /vagrant/output/
