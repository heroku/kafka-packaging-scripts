#!/bin/bash

set -e
set -x

. versions.sh
. aws.sh

BASEDIR=`pwd`
OUTPUT="${BASEDIR}/output"
DEPLOYED="${BASEDIR}/_deployed"
PACKAGES="common rest-utils kafka-rest"

# Note that all files are organized first by packaging system, then by
# release. Organizing by packaging system at the top level will make it easier
# to move things around if we ever decide to change how we distribute
# packages. The organization by release is important for the packaging systems
# where people may want to pin to specific releases easily.

############
# Archives #
############
# for direct user download, including packaged up deb/rpm
mkdir -p "${DEPLOYED}/archive/${CONFLUENT_VERSION}/"
for SCALA_VERSION in $SCALA_VERSIONS; do
    cp "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.tar.gz" \
        "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}.zip" \
        "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}-deb.tar.gz" \
        "${OUTPUT}/confluent-${CONFLUENT_VERSION}-${SCALA_VERSION}-rpm.tar.gz" \
        "${DEPLOYED}/archive/${CONFLUENT_VERSION}/"

    # Generate signatures for verification
    pushd ${DEPLOYED}/archive/${CONFLUENT_VERSION}
    for file in ./*; do
        sha1sum $file > ${file}.sha1.txt
        sha256sum $file > ${file}.sha256.txt
    done
    popd
done

#######
# RPM #
#######
mkdir -p "${DEPLOYED}/rpm/${CONFLUENT_VERSION}/"
eval cp "${OUTPUT}/*.rpm" "${DEPLOYED}/rpm/${CONFLUENT_VERSION}/"
rm -f "${DEPLOYED}/rpm/${CONFLUENT_VERSION}/README.rpm"

# These get copied into place, then we generate/update the index files
vagrant ssh rpm -- createrepo --update "/vagrant/_deployed/rpm/${CONFLUENT_VERSION}/"

# GPG keys -- we want to provide 1 per signed repository so that they are
# associated with that repository instead of a single global key. We should only
# have one, but this is useful if the key is ever compromised. Note that we
# generate one for the deb repo even though we're not uploading the rest of it
# via this path.
mkdir -p "${DEPLOYED}/deb/${CONFLUENT_VERSION}/"
if [ "$SIGN" == "yes" ]; then
    gpg --export --armor --output "${DEPLOYED}/rpm/${CONFLUENT_VERSION}/archive.key" $SIGN_KEY
    gpg --export --armor --output "${DEPLOYED}/deb/${CONFLUENT_VERSION}/archive.key" $SIGN_KEY
fi

# Now we can actually run the upload process for all the files we've arranged
# for archives and RPMs. Debian upload to S3 is managed separately.
aws s3 sync --recursive "${DEPLOYED}/" "s3://${BUCKET}${BUCKET_PREFIX}/"


##########
# Debian #
##########
# Because aptly manages an S3-based repository better than we would
# manage the uploads we just let it do everything.

sed -e "s%PWD%${BASEDIR}%" -e "s%BUCKET%${BUCKET}%" -e "s%PREFIX%${BUCKET_PREFIX}%" -e "s%VERSION%${CONFLUENT_VERSION}%" aptly.conf.template > aptly.conf
REPO="confluent-${CONFLUENT_VERSION}"
APTLY_OPTS="-config=aptly.conf"
APTLY_REPO_OPTS="-distribution=stable -component=main -architectures=all"
aptly "${APTLY_OPTS}" repo list | grep $REPO || aptly "${APTLY_OPTS}" repo create ${APTLY_REPO_OPTS} $REPO
aptly "${APTLY_OPTS}" repo add "$REPO" "${OUTPUT}"
aptly "${APTLY_OPTS}" snapshot create "confluent-${CONFLUENT_VERSION}-${REVISION}" from repo "$REPO"
if [ "$SIGN" == "yes" ]; then
    if [ -n "$SIGN_KEY" ]; then
        APTLY_SIGN_OPTS="-gpg-key $SIGN_KEY"
    fi
else
    APTLY_SIGN_OPTS="--skip-signing=true"
fi
aptly "${APTLY_OPTS}" publish snapshot $APTLY_SIGN_OPTS ${APTLY_REPO_OPTS} "confluent-${CONFLUENT_VERSION}-${REVISION}" "s3:${BUCKET}:"


##############
# Maven jars #
##############

# FIXME because of the way the Kafka build works, we can't actually specify
# SCALA_LANGUAGES here. Also, we unfortunately need to store the info for
# signing here, including the full password. To avoid clobbering the user's real
# gradle.properties we use a fake gradle home
mkdir -p /tmp/fakegradlehome
KEY_ID=`gpg --list-secret-keys $SIGN_KEY | grep -v secring | grep sec | awk -F' ' '{ print $2 }' | awk -F/ '{ print $2 }'`
echo "Enter your GPG key password for $KEY_ID:"
read -s PASSWORD
cat <<EOF > /tmp/fakegradlehome/gradle.properties
signing.keyId=$KEY_ID
signing.password=$PASSWORD
signing.secretKeyRingFile=${HOME}/.gnupg/secring.gpg
EOF

rm -rf /tmp/confluent/kafka
mkdir -p /tmp/confluent
git clone $BASEDIR/repos/kafka.git /tmp/confluent/kafka
pushd /tmp/confluent/kafka
git checkout -b deploy $KAFKA_VERSION
patch -p1 < ${BASEDIR}/patches/kafka-deploy.patch
sed -i '' -e "s%REPOSITORY%s3://${BUCKET}${BUCKET_PREFIX}/maven%" \
    -e "s%SNAPSHOT_REPOSITORY%s3://${BUCKET}${BUCKET_PREFIX}/maven%" build.gradle
gradle --gradle-user-home /tmp/fakegradlehome
./gradlew --gradle-user-home /tmp/fakegradlehome uploadArchivesAll
popd
rm -rf /tmp/confluent/kafka

rm -rf /tmp/fakegradlehome


# The rest of the packages follow a simpler pattern
if [ -z "$BRANCH" ]; then
    BRANCH="$CONFLUENT_VERSION"
fi
for PACKAGE in $PACKAGES; do
    mkdir -p /tmp/confluent
    git clone $BASEDIR/repos/$PACKAGE /tmp/confluent/$PACKAGE
    pushd /tmp/confluent/$PACKAGE
    git checkout -b deploy $BRANCH
    patch -p1 < ${BASEDIR}/patches/${PACKAGE}-deploy.patch
    mvn "-Dconfluent.release.repo=s3://${BUCKET}${BUCKET_PREFIX}/maven" "-Dconfluent.snapshot.repo=s3://${BUCKET}${BUCKET_PREFIX}/maven" clean deploy
    popd
    rm -rf /tmp/confluent/$PACKAGE
done
