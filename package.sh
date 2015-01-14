#!/bin/bash

set -e
set -x

. versions.sh

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


## CONFLUENT-COMMON ##
vagrant ssh rpm -- cp /vagrant/build/common-archive.sh /tmp/common-archive.sh
vagrant ssh rpm -- sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH /tmp/common-archive.sh
vagrant ssh rpm -- cp /vagrant/build/common-rpm.sh /tmp/common-rpm.sh
vagrant ssh rpm -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN /tmp/common-rpm.sh
vagrant ssh deb -- cp /vagrant/build/common-deb.sh /tmp/common-deb.sh
vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN /tmp/common-deb.sh


## REST-UTILS ###
vagrant ssh rpm -- cp /vagrant/build/rest-utils-archive.sh /tmp/rest-utils-archive.sh
vagrant ssh rpm -- sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH /tmp/rest-utils-archive.sh
vagrant ssh rpm -- cp /vagrant/build/rest-utils-rpm.sh /tmp/rest-utils-rpm.sh
vagrant ssh rpm -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN /tmp/rest-utils-rpm.sh
vagrant ssh deb -- cp /vagrant/build/rest-utils-deb.sh /tmp/rest-utils-deb.sh
vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN /tmp/rest-utils-deb.sh


## KAFKA-REST ###
vagrant ssh rpm -- cp /vagrant/build/kafka-rest-archive.sh /tmp/kafka-rest-archive.sh
vagrant ssh rpm -- sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH /tmp/kafka-rest-archive.sh
vagrant ssh rpm -- cp /vagrant/build/kafka-rest-rpm.sh /tmp/kafka-rest-rpm.sh
vagrant ssh rpm -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN /tmp/kafka-rest-rpm.sh
vagrant ssh deb -- cp /vagrant/build/kafka-rest-deb.sh /tmp/kafka-rest-deb.sh
vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION BRANCH=$BRANCH SIGN=$SIGN /tmp/kafka-rest-deb.sh
