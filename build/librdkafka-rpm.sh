#!/bin/bash

set -e
set -x

NAME=librdkafka

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

# Extract librdkafka's branch name without origin/
RDKAFKA_BRANCH=${BRANCH##*/}

# Convert VERSION to VERSION and RPM_RELEASE
if [[ $VERSION == *"-SNAPSHOT"* ]]; then
    VERSION=${VERSION%-SNAPSHOT}
    RPM_RELEASE="0.${REVISION}.SNAPSHOT"
else
    RPM_RELEASE=$REVISION
fi


# Reformat version to <librdkafka_version>_<confluent_version>
VERSION=${RDKAFKA_BRANCH}_confluent$VERSION


mkdir -p /tmp/confluent
cd /tmp/confluent
rm -rf /tmp/confluent/${NAME}
git clone /vagrant/repos/${NAME}.git
cd ${NAME}

git checkout $BRANCH
rm -f *.rpm
export BUILD_NUMBER=$RPM_RELEASE
echo "Using version $VERSION and bnr $BUILD_NUMBER"
make rpm
if [ "x$SIGN" == "xyes" ]; then
    rpm --resign *.rpm || rpm --resign *.rpm || rpm --resign *.rpm
fi
cp *.rpm /vagrant/output/
rm -rf /tmp/confluent
