#!/bin/bash

set -e
set -x

. versions.sh
# All the packages except for Kafka, without the confluent prefix. Kafka needs
# special handling because we support multiple Scala versions. These all need to
# have the same version number currently.
PACKAGES="common rest-utils kafka-rest"

pushd repos
for REPO in "http://git-wip-us.apache.org/repos/asf/kafka.git" "git@github.com:confluentinc/kafka-packaging.git" "git@github.com:confluentinc/common.git" "git@github.com:confluentinc/rest-utils.git" "git@github.com:confluentinc/kafka-rest.git"; do
    REPO_DIR=`basename $REPO`
    if [ ! -e $REPO_DIR ]; then
        # Using mirror makes sure we get copies of all the branches. It also
        # uses a bare repository, which works fine since we want to force the
        # build scripts to copy to a temp directory in the VM anyway in order to
        # avoid cluttering up this directory with build by-products.
        git clone --mirror $REPO
    else
        pushd $REPO_DIR
        git fetch
        popd
    fi
done
popd


if [ "x$SIGN" == "xyes" ]; then
    if [ "x$SIGN_KEY" == "x" ]; then
        SIGN_KEY=`gpg --list-secret-keys | grep uid | sed -e s/uid// -e 's/^ *//' -e 's/ *$//'`
    fi

    cat <<EOF > .rpmmacros
%_signature gpg
%_gpg_path /root/.gnupg
%_gpg_name $SIGN_KEY
%_gpgbin /usr/bin/gpg
EOF
    vagrant ssh rpm -- sudo cp /vagrant/.rpmmacros /root/.rpmmacros
    rm .rpmmacros
fi

## KAFKA ##
vagrant ssh rpm -- cp /vagrant/build/kafka-archive.sh /tmp/kafka-archive.sh
vagrant ssh rpm -- sudo VERSION=$KAFKA_VERSION "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" /tmp/kafka-archive.sh
vagrant ssh rpm -- cp /vagrant/build/kafka-rpm.sh /tmp/kafka-rpm.sh
vagrant ssh rpm -- -t sudo VERSION=$KAFKA_VERSION "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" SIGN=$SIGN /tmp/kafka-rpm.sh
vagrant ssh deb -- cp /vagrant/build/kafka-deb.sh /tmp/kafka-deb.sh
vagrant ssh deb -- -t sudo VERSION=$KAFKA_VERSION "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" SIGN=$SIGN /tmp/kafka-deb.sh


## CONFLUENT PACKAGES ##
for PACKAGE in $PACKAGES; do
    vagrant ssh rpm -- cp "/vagrant/build/${PACKAGE}-archive.sh" "/tmp/${PACKAGE}-archive.sh"
    vagrant ssh rpm -- sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH "/tmp/${PACKAGE}-archive.sh"
    vagrant ssh rpm -- cp "/vagrant/build/${PACKAGE}-rpm.sh" "/tmp/${PACKAGE}-rpm.sh"
    vagrant ssh rpm -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN "/tmp/${PACKAGE}-rpm.sh"
    vagrant ssh deb -- cp "/vagrant/build/${PACKAGE}-deb.sh" "/tmp/${PACKAGE}-deb.sh"
    vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN "/tmp/${PACKAGE}-deb.sh"
done


## COMPILED PACKAGES ##
OUTPUT=`pwd`/output
rm -rf /tmp/confluent-packaging
mkdir -p /tmp/confluent-packaging
pushd /tmp/confluent-packaging

for SCALA_VERSION in $SCALA_VERSIONS; do
    mkdir "confluent-${CONFLUENT_VERSION}"
    pushd "confluent-${CONFLUENT_VERSION}"
    tar -xz --strip-components 1 -f "${OUTPUT}/confluent-kafka-${KAFKA_VERSION}-${SCALA_VERSION}.tar.gz"
    for PACKAGE in $PACKAGES; do
        tar -xz --strip-components 1 -f "${OUTPUT}/confluent-${PACKAGE}-${CONFLUENT_VERSION}.tar.gz"
    done
    popd
    tar -czf "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.tar.gz" "confluent-${CONFLUENT_VERSION}"
    zip -r "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.zip" "confluent-${CONFLUENT_VERSION}"
    rm -rf "confluent-${CONFLUENT_VERSION}"
done

popd
rm -rf /tmp/confluent-packaging
