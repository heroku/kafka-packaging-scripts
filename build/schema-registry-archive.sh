#!/bin/bash

set -e
set -x

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/schema-registry
git clone /vagrant/repos/schema-registry.git
cd schema-registry

git checkout -b archive-$VERSION origin/archive
git merge $BRANCH
make distclean
make archive
cp *.zip *.tar.gz /vagrant/output/
rm -rf /tmp/confluent
