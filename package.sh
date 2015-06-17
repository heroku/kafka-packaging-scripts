#!/bin/bash

set -e
set -x

. versions.sh
# All the packages except for Kafka, without the confluent prefix. Kafka needs
# special handling because we support multiple Scala versions. These all need to
# have the same version number currently.
PACKAGES="common"

pushd repos
for REPO in $KAFKA_REPO \
    $KAFKA_PACKAGING_REPO \
    $COMMON_REPO \
    $REST_UTILS_REPO \
    $SCHEMA_REGISTRY_REPO \
    $KAFKA_REST_REPO \
    $CAMUS_REPO; do
    REPO_DIR=`basename $REPO`
    if [ ! -e $REPO_DIR ]; then
        # Using mirror makes sure we get copies of all the branches. It also
        # uses a bare repository, which works fine since we want to force the
        # build scripts to copy to a temp directory in the VM anyway in order to
        # avoid cluttering up this directory with build by-products.
        git clone --mirror $REPO
    else
        pushd $REPO_DIR
        git fetch --tags
        popd
    fi
done
popd


if [ "x$SIGN" == "xyes" ]; then
    if [ "x$SIGN_KEY" == "x" ]; then
        SIGN_KEY=`gpg --list-secret-keys | grep uid | sed -e s/uid// -e 's/^ *//' -e 's/ *$//'`
    fi
fi

## KAFKA ##
vagrant ssh deb -- cp /vagrant/build/kafka-deb.sh /tmp/kafka-deb.sh
vagrant ssh deb -- -t sudo VERSION=$KAFKA_VERSION REVISION=$REVISION BRANCH=$KAFKA_BRANCH "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" SIGN=$SIGN /tmp/kafka-deb.sh

## CONFLUENT PACKAGES ##
for PACKAGE in $PACKAGES; do
    PACKAGE_BRANCH_VAR="${PACKAGE//-/_}_BRANCH"
    PACKAGE_BRANCH="${!PACKAGE_BRANCH_VAR}"
    if [ -z "$PACKAGE_BRANCH" ]; then
        PACKAGE_BRANCH="$BRANCH"
    fi

    vagrant ssh deb -- cp "/vagrant/build/${PACKAGE}-deb.sh" "/tmp/${PACKAGE}-deb.sh"
    vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION REVISION=$REVISION BRANCH=$PACKAGE_BRANCH SIGN=$SIGN "/tmp/${PACKAGE}-deb.sh"
done


## CONFLUENT PLATFORM PACKAGES ##
# These are also specific to the Scala version so they can't use the standard
# loop above. Note that we also don't have an archive version. Those are handled
# in the compiled packages section below. This step is only used to generate
# system-level dependency packages to make the entire platform easy to
# install. Finally, note that the BRANCH env variable isn't set for these --
# there is no point since they have one fixed branch that they build from
# (debian, stored in this repository).
vagrant ssh deb -- cp /vagrant/build/platform-deb.sh /tmp/platform-deb.sh
vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION REVISION=$REVISION "SCALA_VERSIONS=\"$SCALA_VERSIONS\""  KAFKA_VERSION=$KAFKA_VERSION SIGN=$SIGN /tmp/platform-deb.sh



## COMPILED PACKAGES ##
BASEDIR=`pwd`
OUTPUT="${BASEDIR}/output"

rm -rf /tmp/confluent-packaging
mkdir -p /tmp/confluent-packaging
pushd /tmp/confluent-packaging

# deb
for SCALA_VERSION in $SCALA_VERSIONS; do
    for PKG_TYPE in "deb"; do
        mkdir "confluent-${CONFLUENT_VERSION}"
        pushd "confluent-${CONFLUENT_VERSION}"
        # Getting the actual filenames is a pain because of the version number
        # mangling. We just use globs to find them instead, but this means you
        # *MUST* work with a clean output/ directory
        eval "cp ${OUTPUT}/confluent-kafka-${SCALA_VERSION}*.${PKG_TYPE} ."
        for PACKAGE in $PACKAGES; do
            eval "cp ${OUTPUT}/confluent-${PACKAGE}*.${PKG_TYPE} ."
        done
        cp ${BASEDIR}/installers/install.sh .
        cp ${BASEDIR}/installers/README .
        popd
        tar -czf "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}-${PKG_TYPE}.tar.gz" "confluent-${CONFLUENT_VERSION}"
        rm -rf "confluent-${CONFLUENT_VERSION}"
    done
done

popd
rm -rf /tmp/confluent-packaging
