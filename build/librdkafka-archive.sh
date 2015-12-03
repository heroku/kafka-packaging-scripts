#!/bin/bash

set -e
set -x

NAME=librdkafka

if [ -z "$BRANCH" ]; then
    BRANCH="$VERSION"
fi

# Extract librdkafka's branch name without origin/
RDKAFKA_BRANCH=${BRANCH##*/}

# Reformat version to <librdkafka_version>_<confluent_version>
VERSION=${RDKAFKA_BRANCH}_${VERSION}

mkdir -p /tmp/confluent
pushd /tmp/confluent
rm -rf /tmp/confluent/${NAME}
git clone /vagrant/repos/${NAME}.git
pushd ${NAME}

git checkout $BRANCH
make distclean
make archive
cp *.zip *.tar.gz /vagrant/output/
popd

popd
