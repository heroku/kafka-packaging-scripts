#!/bin/bash

set -e
set -x

# Get a fresh copy of the repository. Unlike most of our other packaging
# scripts, this one requires two repositories since the packaging scripts are
# not kept with the open source code.
mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/kafka-packaging
git clone /vagrant/repos/kafka-packaging.git
cd kafka-packaging
git remote add upstream /vagrant/repos/kafka.git
git fetch --tags upstream

git checkout -b rpm-$VERSION origin/rpm
git merge --no-edit -m "rpm-$VERSION" upstream/$BRANCH
for SCALA_VERSION in $SCALA_VERSIONS; do
    SCALA_VERSION=$SCALA_VERSION make distclean
    SCALA_VERSION=$SCALA_VERSION make rpm
    rm README.rpm
    if [ "x$SIGN" == "xyes" ]; then
        for RPM in *.rpm; do
            rpm --resign $RPM || rpm --resign $RPM || rpm --resign $RPM
        done
    fi
    cp *.rpm /vagrant/output/
done
rm -rf /tmp/confluent
