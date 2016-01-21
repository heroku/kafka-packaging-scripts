#!/bin/bash

. versioning_helpers.sh

###
### Kafka: versioning and packaging configuration
###

# Kafka has its own version and branch settings as it has a special requirements
# in our build setup.  For example, we need to support multiple Scala versions.

# The associated Apache Kafka version.  This variable is used mostly for version number parsing
# in the build scripts (as sometimes the version information in the upstream Kafka branches are
# not matching our desired build configuration) as well as for naming the generated package files.
#
# Examples
# --------
# KAFKA_VERSION="0.8.2.1"
#
KAFKA_VERSION="0.9.0.0"

# Apache Kafka branch that will be used to CP Kafka.  Think: `upstream/<BRANCH>`.
#
# Note that the actual Kafka version(s) used by other CP projects such as `kafka-rest` depends on their respective
# dependency settings defined in `pom.xml`.  It is your responsibility to ensure that the CP Kafka's version (cf.
# `KAFKA_BRANCH`) works with the Kafka versions defined in the various `pom.xml` files of other CP projects, which
# you control by setting `BRANCH` and per-project `*_BRANCH` overrides (see below for details).
#
# Examples
# --------
# KAFKA_BRANCH="0.8.2"
#
KAFKA_BRANCH="0.9.0.0-heroku" # Kafka's 0.9.0.0 release, because this packaging doesn't support building from tags, only branches.

# Build Kafka w/ Scala 2.11 first because of Proactive Support, which depends on the 2.11 variant.
# We must build 2.11 before 2.10 because the Proactive Support projects are only built against
# one variant, which means this variant must be built first.
SCALA_VERSIONS="2.11.7"

# librdkafka follows its own version naming convention, which is different from CP's.
#
# Idea: `librdkafka-<librdkafkaversion>_<vendorversion>`
#
# This setting is important to pick up the correct librdkafka packages from `output/`,
# but as of yet it does not affect the build in any other way, e.g. it is NOT used to
# control which exact code version of librdkafka we are building.
# NOTE: Make sure to synchronize this value with librdkafka_BRANCH below.
LIBRDKAFKA_VERSION="0.9.0"

###
### Proactive Support
###
### Note: By convention the proactive support packages must be built from a /branch/
### of the same name as the Kafka /version/ they are integrating with, i.e. KAFKA_VERSION.
### For example, the code of the support packages for Kafka 0.9.0.0 must be maintained
### in a branch named `0.9.0.0`.  However, the version (pom.xml) of the packages must
### match CONFLUENT_VERSION (like other CP projects such as kafka-rest).

# If "yes" (default), then we integrate Proactive Support into our CP Kafka package.
# This means, for example, that the command line to start/stop a Kafka broker will change
# compared to stock Kafka (cf. Kafka's `bin/kafka-server-{start,stop}.sh`).
#
# Set to "no" to disable PS integration.
# TODO: We have not had the time to test the build when `PS_ENABLED=no` although we are
# confident that it works.  If you plan on building/releasing a version with PS disabled
# you may want to account for some buffer/safety time during release planning.
PS_ENABLED="no"

# The package that contains the (fully assembled) proactive support client.
PS_CLIENT_PACKAGE="support-metrics-client"

# The packages must be listed in the order of their dependencies.  For example,
# support-metrics-common must be listed before support-metrics-fullcollector as
# the latter depends on the former.
PS_PACKAGES="support-metrics-common support-metrics-fullcollector $PS_CLIENT_PACKAGE"


###
### Confluent packages: versioning and packaging configuration
###

# Version of the CP release and also the version of the various CP projects.
#
# *** IMPORTANT ***:
# - This setting must work with the must work with BRANCH settings below.
#   For example, do not set CONFLUENT_VERSION="1.2.3" when BRANCH="origin/4.x".
# - This setting must be aligned with the PACKAGES_BUCKET* and MAVEN_BUCKET
#   settings below.  The S3 buckets we use follow a naming convention that
#   must match CONFLUENT_VERSION.
#
# Examples
# --------
# CONFLUENT_VERSION=1.0.0
# CONFLUENT_VERSION=1.0.1-SNAPSHOT
#
CONFLUENT_VERSION="2.0.0"

# Used for "Revision" field of deb packages and "Release" field of rpm packages.
#
# REVISION should be reset to `1` whenever we bump CONFLUENT_VERSION.
REVISION="1"

# Space-separated list of our C client packages (e.g. librdkafka).
#
# We track these packages separately because they are quite different from our
# Java packages in terms of build process, package names, version naming scheme,
# etc.
#
# IMPORTANT: This variable is quite different from `CP_PACKAGES` below!
#
C_PACKAGES=""

# Space-separated list of all the Java packages except for Kafka, without the
# `confluent-` prefix.  These all need to have the same version number
# currently (cf. CONFLUENT_VERSION).
# Space-separated list of our Java packages (e.g. schema-registry)
#
# The packages must be listed in the order of their dependencies.  For example,
# rest-utils must be listed before kafka-rest as the latter depends on the former.
#
# IMPORTANT: The Proactive Support packages (PS_PACKAGES) MUST NOT be added here!
#
JAVA_PACKAGES="common"

# Space-separated list of all the CP packages except for Kafka.
#
# IMPORTANT: This variable is quite different from `C_PACKAGES` above!
# IMPORTANT: The Proactive Support packages (PS_PACKAGES) MUST NOT be added here!
#
CP_PACKAGES="$JAVA_PACKAGES $C_PACKAGES"

# `BRANCH` is the global setting for build branches of Confluent packages incl. Camus.
#
# Be aware that projects may have different naming conventions for branches.
# If needed, make use of project-specific overrides as described below.
#
# Note: Kafka has its own configuration setting `KAFKA_BRANCH`.
#
# Examples
# --------
# BRANCH="origin/master" # for snapshots
# BRANCH="origin/1.x" # for development/maintenance branches
# BRANCH="v1.0.1" # tag
#
BRANCH="origin/2.x"

# You may add branch overrides for specific projects, if needed.
# Use project_name_using_underscores_BRANCH.
#
# Override examples:
# ------------------
# camus_BRANCH="origin/confluent-master" # branch
# kafka_rest_BRANCH="v1.0" # tag
librdkafka_BRANCH="origin/0.9.0" # librdkafka uses its own versioning scheme, it's NOT tied to Apache Kafka's!


###
### Git repositories
###
### CAVEAT: The short names of the repositories (e.g. "kafka-rest") are
###         currently still hardcoded in the various `build/` scripts.
###         So when you actually rename a project/repository on GitHub you need
###         to update the repository's URL here but also in the corresponding
###         `build/*-{archive,deb,rpm}.sh` scripts of the project..
KAFKA_REPO="git@github.com:heroku/kafka.git"
CAMUS_REPO="git@github.com:confluentinc/camus.git"
COMMON_REPO="git@github.com:confluentinc/common.git"
KAFKA_PACKAGING_REPO="git@github.com:heroku/kafka-packaging.git"
KAFKA_REST_REPO="git@github.com:confluentinc/kafka-rest.git"
REST_UTILS_REPO="git@github.com:confluentinc/rest-utils.git"
SCHEMA_REGISTRY_REPO="git@github.com:confluentinc/schema-registry.git"
KAFKA_CONNECT_HDFS_REPO="git@github.com:confluentinc/kafka-connect-hdfs.git"
KAFKA_CONNECT_JDBC_REPO="git@github.com:confluentinc/kafka-connect-jdbc.git"
SUPPORT_METRICS_COMMON_REPO="git@github.com:confluentinc/support-metrics-common.git"
SUPPORT_METRICS_FULLCOLLECTOR_REPO="git@github.com:confluentinc/support-metrics-fullcollector.git"
SUPPORT_METRICS_CLIENT_REPO="git@github.com:confluentinc/support-metrics-client.git"
LIBRDKAFKA_REPO="git@github.com:edenhill/librdkafka.git"


###
### Repos to build
###
REPOS="$KAFKA_REPO \
    $KAFKA_PACKAGING_REPO \
    $COMMON_REPO \
    $REST_UTILS_REPO \
    $SCHEMA_REGISTRY_REPO \
    $KAFKA_REST_REPO \
    $KAFKA_CONNECT_HDFS_REPO \
    $KAFKA_CONNECT_JDBC_REPO \
    $CAMUS_REPO \
    $LIBRDKAFKA_REPO"


###
### Package signing
###
SIGN="no"
SIGN_KEY="41468433" # packages@confluent.io


###
### AWS/S3 configuration
###
REGION="us-west-2" # S3 region, this is the default for Confluent's account

# Staging S3 bucket to which we deploy the new packages (deb, rpm, tar.gz, zip).
#
# Bucket names must follow the convention `staging-confluent-packages-X.Y.Z`,
# where:
# - X = Major CP release number (cf. CONFLUENT_VERSION)
# - Y = Minor CP release number (cf. CONFLUENT_VERSION)
# - Z = Patch CP release number (cf. CONFLUENT_VERSION)
#
# In the rare case we need to publish a release with REVISION > 1
# (which would happen in case of a packaging mistake, for example),
# then we also add the suffix `-$REVISION`.
#
# Examples:
# staging-confluent-packages-1.0.0    => staging bucket for CP 1.0.0 packages
# staging-confluent-packages-1.2.3-4  => staging bucket for CP 1.2.3 packages with REVISION=4
PACKAGES_BUCKET="staging-confluent-packages-2.0.0"

# S3 bucket that contains all packages for the previous release.
# (previous release: if you want to deploy 1.0.3, then the previous release
# version is 1.0.2).  This bucket is only read from but never written to.
#
# When deploying an initial x.y.0 release (e.g. 1.0.0, 1.3.0, 2.0.0),
# you must set PACKAGES_BUCKET_OF_PREVIOUS_RELEASE="".
#
# This bucket follows the same naming convention as PACKAGES_BUCKET.
#
# Examples:
# confluent-packages-1.0.0  (production S3 bucket)
PACKAGES_BUCKET_OF_PREVIOUS_RELEASE=""

# Staging S3 bucket to which we deploy the new maven artifacts (jars).
#
# Bucket names must follow the convention `staging-confluent-packages-maven-X.Y.Z`,
# where:
# - X = Major CP release number (cf. CONFLUENT_VERSION)
# - Y = Minor CP release number (cf. CONFLUENT_VERSION)
# - Z = Patch CP release number (cf. CONFLUENT_VERSION)
#
# In the rare case we need to publish a release with REVISION > 1
# (which would happen in case of a packaging mistake, for example),
# then we also add the suffix `-$REVISION`.
#
# Examples:
# staging-confluent-packages-maven-1.0.0    => staging bucket for CP 1.0.0 maven artifacts
# staging-confluent-packages-maven-1.2.3-4  => staging bucket for CP 1.2.3 maven artifacts with REVISION=4
MAVEN_BUCKET="staging-confluent-packages-maven-2.0.0"

# Production S3 bucket that contains our production Maven repository.
# This bucket is only read from but never written to.
#
# NOTE: You should never need to modify this setting!
MAVEN_BUCKET_PRODUCTION="confluent-packages-maven"

# Top-level bucket sub-directory (cf. PACKAGES_BUCKET) for archive packages
PACKAGES_BUCKET_ARCHIVE_BASE="archive"
# Top-level bucket sub-directory (cf. PACKAGES_BUCKET) for deb packages
PACKAGES_BUCKET_DEB_BASE="deb"
# Top-level bucket sub-directory (cf. PACKAGES_BUCKET) for rpm packages
PACKAGES_BUCKET_RPM_BASE="rpm"

BUCKET_POLICY_FILE_TEMPLATE="bucket-policy-public-read.json.template"
BUCKET_POLICY_FILE="bucket-policy-public-read.json"


###
### Enabling/disabling tests
###
#
# Set SKIP_TESTS to "yes" to disable tests, to "no" to enable tests.
SKIP_TESTS="no"

# You may add overrides for specific projects, if needed.
# Use project_name_using_underscores_SKIP_TESTS.
#
# You can also define the special `kafka_SKIP_TESTS`, which will skip the tests for any project we are building as part
# of the Kafka build.  As of Dec 2015, this includes: Kafka itself (note that the build targets we use for Kafka
# actually don't run Kafka's test suite anyways, so we haven't included a SKIP_TESTS switch for Kafka's gradle build)
# plus the Proactive Support components aka `support-metrics-{common,fullcollector,client}`.
#
# Note: There are no build/package-time tests for librdkafka or libserdes,
#       so the global SKIP_TESTS setting and any per-project *_SKIP_TESTS
#       settings have no effect for these projects.
#
# Override examples:
# ------------------
# kafka_rest_SKIP_TESTS="yes"
rest_utils_SKIP_TESTS="yes"


###
### Package verification rules
###
PACKAGE_MIN_FILE_SIZE_BYTES=10000

###
### Misc settings
###
OUTPUT_DIRECTORY="output" # local directory; stores generated packages; note: build/*.sh scripts still hardcode this (`/vagrant/output`)
DEPLOYED_DIRECTORY="_deployed" # local directory; contains directory tree for S3 deployment uploads
TEMP_DIRECTORY="_temp" # local directory; used for extracting deb/rpm packages of a previous release from an S3 bucket
REPOS_DIRECTORY="repos" # local directory; stores local checkout of git repos such as KAFKA_REPO

###
### Build optimization/tuning
###
# If "yes", then we delete the contents of REPOS_DIRECTORY at the beginning of the packaging step ("no" means keep any
# existing contents).  The recommended setting is "yes" to ensure that any recent changes to the git repositories, e.g.
# new commits made in-between packaging runs, are properly pulled to our local repository checkouts.
PURGE_REPOS_DIRECTORY_BEFORE_PACKAGING="yes"


###
### Input validation of settings defined above
###

if [ -z "$CONFLUENT_VERSION" ]; then
  echo "ERROR: CONFLUENT_VERSION must be set"
  exit 1
fi
declare -r CONFLUENT_VERSION_MIN_LENGTH=5 # 5 for "x.y.z"
if [ ${#CONFLUENT_VERSION} -lt $CONFLUENT_VERSION_MIN_LENGTH ]; then
  echo "ERROR: CONFLUENT_VERSION must have a length >= ${CONFLUENT_VERSION_MIN_LENGTH} (it currently has length ${#CONFLUENT_VERSION})"
  exit 1
fi

# Ensure that buckets are configured.
if [ -z "$PACKAGES_BUCKET" ]; then
  echo "ERROR: PACKAGES_BUCKET must be set"
  exit 1
fi
if [ -z "$MAVEN_BUCKET" ]; then
  echo "ERROR: MAVEN_BUCKET must be set"
  exit 1
fi
if [ -z "$MAVEN_BUCKET_PRODUCTION" ]; then
  echo "ERROR: MAVEN_BUCKET_PRODUCTION must be set"
  exit 1
fi

# Ensure that we deploy packages only to staging S3 buckets
if [[ "$PACKAGES_BUCKET" != staging-confluent-packages-* ]]; then
  echo "ERROR: PACKAGES_BUCKET must start with 'staging-confluent-packages-'"
  exit 1
fi

# Ensure that we deploy maven artifacts only to staging S3 buckets
if [[ "$MAVEN_BUCKET" != staging-confluent-packages-maven-* ]]; then
  echo "ERROR: MAVEN_BUCKET must start with 'staging-confluent-packages-maven-'"
  exit 1
fi

# Ensure that the version identifier in the S3 buckets match CONFLUENT_VERSION.
if [ `rpm_version $CONFLUENT_VERSION` != `cp_release_from_versioned_s3_bucket $PACKAGES_BUCKET` ]; then
  echo "ERROR: Version identifier in PACKAGES_BUCKET ($PACKAGES_BUCKET) is not compatible with" \
    "CONFLUENT_VERSION ($CONFLUENT_VERSION)"
  exit 1
fi
if [ `rpm_version $CONFLUENT_VERSION` != `cp_release_from_versioned_s3_bucket $MAVEN_BUCKET` ]; then
  echo "ERROR: Version identifier in MAVEN_BUCKET ($MAVEN_BUCKET) is not compatible with" \
    "CONFLUENT_VERSION ($CONFLUENT_VERSION)"
  exit 1
fi
