#!/bin/bash

set -e
set -x

MYSELF=`basename $0`
MY_DIR=`echo $(cd $(dirname $0); pwd)`

. $MY_DIR/settings.sh
. $MY_DIR/aws.sh

# We must export this env variable, which is defined in settings.sh, for the subsequent steps to work.
export MAVEN_BUCKET

# Detect jdk version
jdk=`javac -version 2>&1 | cut -d ' ' -f 2`
ver=`echo $jdk | cut -d '.' -f 2`
if (( $ver < 7 )); then
    echo "Found jdk version $jdk"
    echo "Despite the fact that we support Java 1.6+, you need to run this deploy script with JDK 1.7+. This is required because the Maven S3 Wagon requires 1.7+. It's safe at this point because the specs in the projects target 1.6 and other testing validates our builds against earlier version."
    exit 1
fi

##############
# Maven jars #
##############

# S3 wagon uses a different environment variable for AWS_SECRET_ACCESS_KEY
# (cf. https://github.com/jcaddel/maven-s3-wagon/wiki/Authentication)
export AWS_SECRET_KEY="$AWS_SECRET_ACCESS_KEY"

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

rm -rf /tmp/confluent/kafka-packaging
mkdir -p /tmp/confluent
git clone $MY_DIR/$REPOS_DIRECTORY/kafka-packaging.git /tmp/confluent/kafka-packaging
pushd /tmp/confluent/kafka-packaging
git remote add upstream $MY_DIR/$REPOS_DIRECTORY/kafka.git
git fetch --tags upstream

git checkout -b "deploy-$KAFKA_VERSION" origin/archive
git merge --no-edit -m "deploy-$KAFKA_VERSION" upstream/$KAFKA_BRANCH
make apply-patches # Note that this should also include the confluent-specific version # patch
patch -p1 < ${MY_DIR}/patches/kafka-deploy.patch
sed -i '' -e "s%REPOSITORY%s3://${MAVEN_BUCKET}${MAVEN_BUCKET_PREFIX}/maven%" \
    -e "s%SNAPSHOT_REPOSITORY%s3://${MAVEN_BUCKET}${MAVEN_BUCKET_PREFIX}/maven%" build.gradle
gradle --gradle-user-home /tmp/fakegradlehome
./gradlew --gradle-user-home /tmp/fakegradlehome uploadArchivesAll
popd
rm -rf /tmp/confluent/kafka-packaging

rm -rf /tmp/fakegradlehome


# The rest of the packages follow a simpler pattern
if [ -z "$BRANCH" ]; then
    BRANCH="$CONFLUENT_VERSION"
fi
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

    mkdir -p /tmp/confluent
    rm -rf /tmp/confluent/$PACKAGE
    git clone $MY_DIR/$REPOS_DIRECTORY/$PACKAGE /tmp/confluent/$PACKAGE
    pushd /tmp/confluent/$PACKAGE
    git checkout -b deploy $PACKAGE_BRANCH
    patch -p1 < ${MY_DIR}/patches/${PACKAGE}-deploy.patch
    MAVEN_OPTS=""
    if [ "$PACKAGE_SKIP_TESTS" = "yes" ]; then
      MAVEN_OPTS="$MAVEN_OPTS -DskipTests=true"
    fi
    mvn $MAVEN_OPTS "-Dconfluent.release.repo=s3://${MAVEN_BUCKET}${MAVEN_BUCKET_PREFIX}/maven" "-Dconfluent.snapshot.repo=s3://${MAVEN_BUCKET}${MAVEN_BUCKET_PREFIX}/maven" clean deploy
    popd
    rm -rf /tmp/confluent/$PACKAGE
done
