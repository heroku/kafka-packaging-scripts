#!/bin/bash

set -e
set -x

mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/kafka-platform
# platform packaging scripts are stored in the top-level packaging.git repo
git clone /vagrant/ kafka-platform
cd kafka-platform
git checkout -b rpm-$VERSION origin/rpm

for SCALA_VERSION in $SCALA_VERSIONS; do
    SCALA_VERSION=$SCALA_VERSION make distclean
    SCALA_VERSION=$SCALA_VERSION make rpm
    if [ "x$SIGN" == "xyes" ]; then
        for RPM in *.rpm; do
            rpm --resign $RPM || rpm --resign $RPM || rpm --resign $RPM
        done
    fi
    cp *.rpm /vagrant/output/
done
rm -rf /tmp/confluent
