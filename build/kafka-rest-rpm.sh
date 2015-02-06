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
cd kafka-rest

git checkout -b rpm-$VERSION origin/rpm
git merge --no-edit $BRANCH
make distclean
make rpm
if [ "x$SIGN" == "xyes" ]; then
    rpm --resign *.rpm || rpm --resign *.rpm || rpm --resign *.rpm
fi
cp *.rpm /vagrant/output/
rm -rf /tmp/confluent
