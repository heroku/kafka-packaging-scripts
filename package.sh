#!/bin/bash

set -e
set -x

MYSELF=`basename $0`
MY_DIR=`echo $(cd $(dirname $0); pwd)`

pushd `pwd`
pushd $MY_DIR

. $MY_DIR/settings.sh

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
vagrant ssh rpm -- sudo VERSION=$KAFKA_VERSION REVISION=$REVISION BRANCH=$KAFKA_BRANCH "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" "PS_ENABLED=\"$PS_ENABLED\"" "PS_PACKAGES=\"$PS_PACKAGES\"" "PS_CLIENT_PACKAGE=\"$PS_CLIENT_PACKAGE\"" "CONFLUENT_VERSION=\"$CONFLUENT_VERSION\"" /tmp/kafka-archive.sh
vagrant ssh rpm -- cp /vagrant/build/kafka-rpm.sh /tmp/kafka-rpm.sh
vagrant ssh rpm -- -t sudo VERSION=$KAFKA_VERSION REVISION=$REVISION BRANCH=$KAFKA_BRANCH "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" "PS_ENABLED=\"$PS_ENABLED\"" "PS_PACKAGES=\"$PS_PACKAGES\"" "PS_CLIENT_PACKAGE=\"$PS_CLIENT_PACKAGE\"" "CONFLUENT_VERSION=\"$CONFLUENT_VERSION\"" SIGN=$SIGN /tmp/kafka-rpm.sh
vagrant ssh deb -- cp /vagrant/build/kafka-deb.sh /tmp/kafka-deb.sh
vagrant ssh deb -- -t sudo VERSION=$KAFKA_VERSION REVISION=$REVISION BRANCH=$KAFKA_BRANCH "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" "PS_ENABLED=\"$PS_ENABLED\"" "PS_PACKAGES=\"$PS_PACKAGES\"" "PS_CLIENT_PACKAGE=\"$PS_CLIENT_PACKAGE\"" "CONFLUENT_VERSION=\"$CONFLUENT_VERSION\"" SIGN=$SIGN /tmp/kafka-deb.sh

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

    vagrant ssh rpm -- cp "/vagrant/build/${PACKAGE}-archive.sh" "/tmp/${PACKAGE}-archive.sh"
    vagrant ssh rpm -- sudo VERSION=$CONFLUENT_VERSION REVISION=$REVISION BRANCH=$PACKAGE_BRANCH SKIP_TESTS=$PACKAGE_SKIP_TESTS "/tmp/${PACKAGE}-archive.sh"
    vagrant ssh rpm -- cp "/vagrant/build/${PACKAGE}-rpm.sh" "/tmp/${PACKAGE}-rpm.sh"
    vagrant ssh rpm -- -t sudo VERSION=$CONFLUENT_VERSION REVISION=$REVISION BRANCH=$PACKAGE_BRANCH SKIP_TESTS=$PACKAGE_SKIP_TESTS SIGN=$SIGN "/tmp/${PACKAGE}-rpm.sh"
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
vagrant ssh rpm -- cp /vagrant/build/platform-rpm.sh /tmp/platform-rpm.sh
vagrant ssh rpm -- -t sudo VERSION=$CONFLUENT_VERSION REVISION=$REVISION "SCALA_VERSIONS=\"$SCALA_VERSIONS\"" KAFKA_VERSION=$KAFKA_VERSION SIGN=$SIGN /tmp/platform-rpm.sh
vagrant ssh deb -- cp /vagrant/build/platform-deb.sh /tmp/platform-deb.sh
vagrant ssh deb -- -t sudo VERSION=$CONFLUENT_VERSION REVISION=$REVISION "SCALA_VERSIONS=\"$SCALA_VERSIONS\""  KAFKA_VERSION=$KAFKA_VERSION SIGN=$SIGN /tmp/platform-deb.sh



## COMPILED PACKAGES ##
rm -rf /tmp/confluent-packaging
mkdir -p /tmp/confluent-packaging
pushd /tmp/confluent-packaging

ABS_OUTPUT_DIRECTORY=${MY_DIR}/${OUTPUT_DIRECTORY}

# zip/tar.gz
for SCALA_VERSION in $SCALA_VERSIONS; do
    PACKAGE_ROOT="confluent-${CONFLUENT_VERSION}"
    mkdir $PACKAGE_ROOT
    pushd $PACKAGE_ROOT
    tar -xz --strip-components 1 -f "${ABS_OUTPUT_DIRECTORY}/confluent-kafka-${KAFKA_VERSION}-${SCALA_VERSION}.tar.gz"
    for PACKAGE in $CP_PACKAGES; do
      if [ "$PACKAGE" = "librdkafka" ]; then
        # TODO: librdkafka (and possibly further C-based packages) requires special treatment.
        # Until we have identified a clear pattern for these "special" packages we hardcode
        # this special-casing of librdkafka.
        #
        # Place the librdkafka tarball as-is (i.e. do not extract) under `src/`.
        # The tarball contains the sources so there isn't a more appropriate place
        # to handle the contents of this tarball.
        LIBRDKAFKA_REL_DESTINATION_DIR="src/"
        mkdir $LIBRDKAFKA_REL_DESTINATION_DIR
        cp "${ABS_OUTPUT_DIRECTORY}/librdkafka-${LIBRDKAFKA_VERSION}_${CONFLUENT_VERSION}.tar.gz" $LIBRDKAFKA_REL_DESTINATION_DIR
        cp "${ABS_OUTPUT_DIRECTORY}/librdkafka-${LIBRDKAFKA_VERSION}_${CONFLUENT_VERSION}.zip" $LIBRDKAFKA_REL_DESTINATION_DIR
      else
        # A "normal" CP packages like schema-registry.
        tar -xz --strip-components 1 -f "${ABS_OUTPUT_DIRECTORY}/confluent-${PACKAGE}-${CONFLUENT_VERSION}.tar.gz"
      fi
    done
    cp ${MY_DIR}/installers/README.archive .
    popd
    # TODO: the tar.gz should not contain the librdkafka zip file
    tar -czf "${ABS_OUTPUT_DIRECTORY}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.tar.gz" $PACKAGE_ROOT
    # TODO: the zip should not contain the librdkafka tar.gz file
    zip -r "${ABS_OUTPUT_DIRECTORY}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.zip" $PACKAGE_ROOT
    rm -rf $PACKAGE_ROOT
done

# deb/rpm
for SCALA_VERSION in $SCALA_VERSIONS; do
    for PKG_TYPE in "deb" "rpm"; do
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
