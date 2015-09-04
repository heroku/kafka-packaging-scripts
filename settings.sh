###
### Kafka: versioning and packaging configuration
###

# Kafka has its own version and branch settings as it has a special requirements
# in our build setup.  For example, we need to support multiple Scala versions.
KAFKA_VERSION="0.8.2.1" # Will eventually be 0.8.2.2
KAFKA_BRANCH="0.8.2"
SCALA_VERSIONS="2.9.1 2.9.2 2.10.4 2.11.5"


###
### Confluent packages: versioning and packaging configuration
###
CONFLUENT_VERSION="1.0.1-SNAPSHOT" # Examples: `1.0`, `1.0.1-SNAPSHOT`; must work with BRANCH settings below

# Used for "Revision" field of deb packages and "Release" field of rpm packages.
#
# REVISION should be reset to `1` whenever we bump CONFLUENT_VERSION.
REVISION="1"

# Space-separated list of all the packages except for Kafka, without the
# `confluent-` prefix.  These all need to have the same version number
# currently (cf. CONFLUENT_VERSION).
#
# The packages must be listed in the order of their dependencies.  For example,
# rest-utils must be listed before kafka-rest as the latter depends on the former.
CP_PACKAGES="common rest-utils schema-registry kafka-rest camus"

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
#
BRANCH="origin/1.x"

# You may add branch overrides for specific projects, if needed.
# Use project_name_using_underscores_BRANCH.
#
# Override examples:
# ------------------
# camus_BRANCH="origin/confluent-master" # branch
# kafka_rest_BRANCH="v1.0" # tag


###
### Git repositories
###
KAFKA_REPO="http://git-wip-us.apache.org/repos/asf/kafka.git"
CAMUS_REPO="git@github.com:confluentinc/camus.git"
COMMON_REPO="git@github.com:confluentinc/common.git"
KAFKA_PACKAGING_REPO="git@github.com:confluentinc/kafka-packaging.git"
KAFKA_REST_REPO="git@github.com:confluentinc/kafka-rest.git"
REST_UTILS_REPO="git@github.com:confluentinc/rest-utils.git"
SCHEMA_REGISTRY_REPO="git@github.com:confluentinc/schema-registry.git"


###
### Package signing
###
SIGN="yes"
SIGN_KEY=""


###
### AWS/S3 configuration
###
REGION="us-west-2" # S3 region, this is the default for Confluent's account
PACKAGES_BUCKET="staging-confluent-packages-1.0.1"
MAVEN_BUCKET="staging-confluent-packages-maven-1.0.1"


###
### Enabling/disabling tests
###
#
# Set SKIP_TESTS to "yes" to disable tests, to "no" to enable tests.
SKIP_TESTS="no"

# You may add overrides for specific projects, if needed.
# Use project_name_using_underscores_SKIP_TESTS.
#
# Override examples:
# ------------------
# kafka_rest_SKIP_TESTS="yes"
#
camus_SKIP_TESTS="yes" # We do not run tests for Camus.


###
### Package verification rules
###
PACKAGE_MIN_FILE_SIZE_BYTES=10000

###
### Misc settings
###
OUTPUT_DIRECTORY="output" # local directory; stores generated packages
DEPLOYED_DIRECTORY="_deployed" # local directory; contains directory tree for S3 deployment uploads
