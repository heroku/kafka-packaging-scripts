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

git checkout -b rpm-$VERSION origin/rpm
git merge --no-edit $BRANCH
make distclean
make rpm
if [ "x$SIGN" == "xyes" ]; then
    rpm --resign *.rpm || rpm --resign *.rpm || rpm --resign *.rpm
fi
cp *.rpm /vagrant/output/
