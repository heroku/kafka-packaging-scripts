#!/bin/bash
#
# Builds all Java maven artifacts of CP and deploys them as a maven repository to a staging S3 bucket.

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
    echo "We do not support Java versions < 1.7 anymore.  Also, you must run this deploy script with JDK 1.7+ because the Maven S3 Wagon requires 1.7+."
    exit 1
fi

##############
# Maven jars #
##############

# S3 wagon uses a different environment variable for AWS_SECRET_ACCESS_KEY
# (cf. https://github.com/jcaddel/maven-s3-wagon/wiki/Authentication)
export AWS_SECRET_KEY="$AWS_SECRET_ACCESS_KEY"

declare -r BUILD_ROOT="/tmp/confluent-artifacts"
declare -r KAFKA_BUILD_ROOT="$BUILD_ROOT/kafka-packaging"

declare -r MAVEN_REPOSITORY_RELEASE_S3_URL="s3://${MAVEN_BUCKET}${MAVEN_BUCKET_PREFIX}/maven"
declare -r CONFLUENT_STAGING_MAVEN_REPOSITORY_URL="http://${MAVEN_BUCKET}${MAVEN_BUCKET_PREFIX}.s3.amazonaws.com/maven"

###
### Kafka
###

# FIXME because of the way the Kafka build works, we can't actually specify
# SCALA_LANGUAGES here. Also, we unfortunately need to store the info for
# signing here, including the full password. To avoid clobbering the user's real
# gradle.properties we use a fake gradle home
FAKE_GRADLE_HOME="/tmp/fakegradlehome"
mkdir -p $FAKE_GRADLE_HOME
KEY_ID=`gpg --list-secret-keys $SIGN_KEY | grep -v secring | grep sec | awk -F' ' '{ print $2 }' | awk -F/ '{ print $2 }'`
echo "Enter your GPG key password for $KEY_ID:"
read -s PASSWORD
cat <<EOF > $FAKE_GRADLE_HOME/gradle.properties
signing.keyId=$KEY_ID
signing.password=$PASSWORD
signing.secretKeyRingFile=${HOME}/.gnupg/secring.gpg
EOF

rm -rf $KAFKA_BUILD_ROOT
mkdir -p $BUILD_ROOT
git clone $MY_DIR/$REPOS_DIRECTORY/kafka-packaging.git $KAFKA_BUILD_ROOT
pushd $KAFKA_BUILD_ROOT
git remote add upstream $MY_DIR/$REPOS_DIRECTORY/kafka.git
git fetch --tags upstream
git checkout -b "deploy-$KAFKA_VERSION" origin/archive
git merge --no-edit -m "deploy-$KAFKA_VERSION" upstream/$KAFKA_BRANCH
make apply-patches # Note that this should also include the confluent-specific version # patch
patch -p1 < ${MY_DIR}/patches/kafka-deploy.patch
sed -i '' -e "s%REPOSITORY%${MAVEN_REPOSITORY_RELEASE_S3_URL}%" \
    -e "s%SNAPSHOT_REPOSITORY%${MAVEN_REPOSITORY_RELEASE_S3_URL}%" build.gradle
gradle --gradle-user-home $FAKE_GRADLE_HOME
./gradlew --gradle-user-home $FAKE_GRADLE_HOME uploadArchivesAll
popd
rm -rf $KAFKA_BUILD_ROOT
rm -rf $FAKE_GRADLE_HOME


###
### Other CP (java-based) packages
### The rest of the packages follow a simpler pattern
###
if [ -z "$BRANCH" ]; then
    BRANCH="$CONFLUENT_VERSION"
fi
for PACKAGE in $JAVA_PACKAGES; do
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

    mkdir -p $BUILD_ROOT
    rm -rf $BUILD_ROOT/$PACKAGE
    git clone $MY_DIR/$REPOS_DIRECTORY/$PACKAGE $BUILD_ROOT/$PACKAGE
    pushd $BUILD_ROOT/$PACKAGE
    git checkout -b deploy $PACKAGE_BRANCH
    patch -p1 < ${MY_DIR}/patches/${PACKAGE}-deploy.patch
    MAVEN_OPTS=""
    if [ "$PACKAGE_SKIP_TESTS" = "yes" ]; then
      MAVEN_OPTS="$MAVEN_OPTS -DskipTests=true"
    fi

    mvn $MAVEN_OPTS \
      "-Dconfluent.release.repo=${MAVEN_REPOSITORY_RELEASE_S3_URL}" \
      "-Dconfluent.snapshot.repo=${MAVEN_REPOSITORY_RELEASE_S3_URL}" \
      "-Dconfluent.maven.repo=${CONFLUENT_STAGING_MAVEN_REPOSITORY_URL}" \
      clean deploy
    popd
    rm -rf $BUILD_ROOT/$PACKAGE
done
