#!/bin/bash

set -e
set -x

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/camus
git clone /vagrant/repos/camus.git
cd camus

git checkout -b archive-$VERSION origin/archive
git merge $BRANCH
make distclean
make archive
cp *.zip *.tar.gz /vagrant/output/
