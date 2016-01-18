#!/bin/bash

set -e
set -x

MYSELF=`basename $0`
MY_DIR=`echo $(cd $(dirname $0); pwd)`

pushd `pwd`
pushd $MY_DIR

. $MY_DIR/settings.sh
. $MY_DIR/versioning_helpers.sh

# Ensure that important local directories are in good shape.
if [ ! -d $OUTPUT_DIRECTORY ]; then
  git checkout $OUTPUT_DIRECTORY
fi

if [ "$PURGE_REPOS_DIRECTORY_BEFORE_PACKAGING" = "yes" ]; then
  rm -rf ${MY_DIR}/${REPOS_DIRECTORY}
fi
if [ ! -d $REPOS_DIRECTORY ]; then
  git checkout $REPOS_DIRECTORY
fi

# Ensure that local clones also track any required upstream packaging branches.
# If they don't then the subsequent git clones in the VM, which are cloned from
# this local clone, will fail with errors such as:
#
#     fatal: Cannot update paths and switch to branch 'rpm-1.0' at the same time.
#     Did you intend to checkout 'origin/rpm' which can not be resolved as commit?
#
# This is because after `git clone /vagrant/ kafka-platform` in the VM, the VM's
# origin is pointing # to the local clone (not upstream's origin), and the local
# clone may not yet track the upstream branches such as `origin/rpm`.
for remote_branch in rpm debian confluent-platform; do
  echo "Tracking remote branch '$remote_branch'"
  git branch -d $remote_branch || true
  git branch --track $remote_branch origin/$remote_branch
done

pushd $REPOS_DIRECTORY
for REPO in $REPOS ; do
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

## KAFKA ##
KAFKA_BUILD_SKIP_TESTS="yes"
if [ ! -z "$kafka_SKIP_TESTS" ]; then
  KAFKA_BUILD_SKIP_TESTS="$kafka_SKIP_TESTS"
else
  if [ ! -z "$SKIP_TESTS" ]; then
    KAFKA_BUILD_SKIP_TESTS="$SKIP_TESTS"
  fi
fi

vagrant ssh deb -- cp /vagrant/build/kafka-deb.sh /tmp/kafka-deb.sh
vagrant ssh deb -- -t sudo VERSION=$KAFKA_VERSION REVISION=$REVISION BRANCH=$KAFKA_BRANCH "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" "PS_ENABLED=\"$PS_ENABLED\"" "PS_PACKAGES=\"$PS_PACKAGES\"" "PS_CLIENT_PACKAGE=\"$PS_CLIENT_PACKAGE\"" "CONFLUENT_VERSION=\"$CONFLUENT_VERSION\"" SKIP_TESTS=$KAFKA_BUILD_SKIP_TESTS SIGN=$SIGN /tmp/kafka-deb.sh

## CONFLUENT PACKAGES ##
for PACKAGE in $CP_PACKAGES; do
    PACKAGE_BRANCH_VAR="${PACKAGE//-/_}_BRANCH"
    PACKAGE_BRANCH="${!PACKAGE_BRANCH_VAR}"
    if [ -z "$PACKAGE_BRANCH" ]; then
        PACKAGE_BRANCH="$BRANCH"
    fi

    PACKAGE_SKIP_TESTS_VAR="${PACKAGE//-/_}_SKIP_TESTS"
    PACKAGE_SKIP_TESTS="${!PACKAGE_SKIP_TESTS_VAR}"
    if [ -z "$PACKAGE_SKIP_TESTS" ]; then
        PACKAGE_SKIP_TESTS="$SKIP_TESTS"
    fi

    vagrant ssh deb -- cp "/vagrant/build/${PACKAGE}-deb.sh" "/tmp/${PACKAGE}-deb.sh"
    vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION REVISION=$REVISION BRANCH=$PACKAGE_BRANCH SKIP_TESTS=$PACKAGE_SKIP_TESTS SIGN=$SIGN "/tmp/${PACKAGE}-deb.sh"
done


## CONFLUENT PLATFORM PACKAGES ##
# These are also specific to the Scala version so they can't use the standard
# loop above. Note that we also don't have an archive version. Those are handled
# in the compiled packages section below. This step is only used to generate
# system-level dependency packages to make the entire platform easy to
# install. Finally, note that the BRANCH env variable isn't set for these --
# there is no point since they have one fixed branch that they build from (rpm
# or debian, stored in this repository).

DEB_VERSION=`deb_version_field $CONFLUENT_VERSION $REVISION`
KAFKA_DEB_VERSION=`deb_version_field $KAFKA_VERSION $REVISION`
LIBRDKAFKA_DEB_VERSION=`deb_version_field_librdkafka $LIBRDKAFKA_VERSION $CONFLUENT_VERSION $REVISION`
vagrant ssh deb -- cp /vagrant/build/platform-deb.sh /tmp/platform-deb.sh
vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION DEB_VERSION=$DEB_VERSION "SCALA_VERSIONS=\"$SCALA_VERSIONS\""  KAFKA_DEB_VERSION=$KAFKA_DEB_VERSION LIBRDKAFKA_DEB_VERSION=$LIBRDKAFKA_DEB_VERSION SIGN=$SIGN /tmp/platform-deb.sh


## COMPILED PACKAGES ##
rm -rf /tmp/confluent-packaging
mkdir -p /tmp/confluent-packaging
pushd /tmp/confluent-packaging

ABS_OUTPUT_DIRECTORY=${MY_DIR}/${OUTPUT_DIRECTORY}

# deb
for SCALA_VERSION in $SCALA_VERSIONS; do
    for PKG_TYPE in "deb"; do
        PACKAGE_ROOT="confluent-${CONFLUENT_VERSION}"
        mkdir $PACKAGE_ROOT
        pushd $PACKAGE_ROOT
        # Getting the actual filenames is a pain because of the version number
        # mangling. We just use globs to find them instead, but this means you
        # *MUST* work with a clean output/ directory
        eval "cp ${ABS_OUTPUT_DIRECTORY}/confluent-kafka-${SCALA_VERSION}*.${PKG_TYPE} ."
        for PACKAGE in $CP_PACKAGES; do
          if [ "$PACKAGE" = "librdkafka" ]; then
            # TODO: librdkafka (and possibly further C-based packages) requires special treatment.
            eval "cp ${ABS_OUTPUT_DIRECTORY}/librdkafka*${LIBRDKAFKA_VERSION}*.${PKG_TYPE} ."
          else
            eval "cp ${ABS_OUTPUT_DIRECTORY}/confluent-${PACKAGE}*.${PKG_TYPE} ."
          fi
        done
        cp ${MY_DIR}/installers/install.sh .
        cp ${MY_DIR}/installers/README .
        popd
        tar -czf "${ABS_OUTPUT_DIRECTORY}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}-${PKG_TYPE}.tar.gz" $PACKAGE_ROOT
        rm -rf $PACKAGE_ROOT
    done
done

popd
rm -rf /tmp/confluent-packaging

popd
