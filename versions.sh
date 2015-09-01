###
### Versioning and packaging configuration
### (see also configuration of branches below)
###
CONFLUENT_VERSION="1.0.1-SNAPSHOT" # Examples: `1.0`, `1.0.1-SNAPSHOT`; must work with BRANCH settings below

# Used for "Revision" information of deb packages and
# "Release" information for rpm packages.
#
# REVISION is reset to `1` whenever we bump CONFLUENT_VERSION.
REVISION="1"

# All the packages except for Kafka, without the `confluent-` prefix. Kafka needs
# special handling because we support multiple Scala versions. These all need to
# have the same version number currently (cf. CONFLUENT_VERSION).
#
# The packages must be listed in the order of their dependencies.  For example,
# rest-utils must be listed before kafka-rest as the latter depends on the former.
CP_PACKAGES="common rest-utils schema-registry kafka-rest camus"

KAFKA_VERSION="0.8.2.1" # Will eventually be 0.8.2.2
SCALA_VERSIONS="2.9.1 2.9.2 2.10.4 2.11.5"

SIGN="yes"
SIGN_KEY=""


###
### AWS/S3 configuration
###
REGION="us-west-2" # S3 region, this is the default for Confluent's account


###
### Local directories used for packaging
###
OUTPUT_DIRECTORY="output" # stores generated packages

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
### Branches from which the packages will be built
###

# Kafka has its own branch variable as it has a special role in our build setup.
KAFKA_BRANCH="0.8.2"

# Confluent packages
#
# `BRANCH` is the global setting for build branches of Confluent packages.
#
# Note that projects may have different naming conventions for branches.
# If needed, make use of project-specific overrides as described below.
#
# Examples
# --------
# BRANCH="origin/master" # for snapshots
# BRANCH="origin/1.x" # for development/maintenance branches
#
BRANCH="origin/master"

# Branch overrides for specific projects.  Use project_name_using_underscores_BRANCH.
#
# Override examples:
# ------------------
# camus_BRANCH="origin/confluent-master" # branch
# kafka_rest_BRANCH="v1.0" # tag
#
camus_BRANCH="origin/1.x"
common_BRANCH="origin/1.x"
kafka_rest_BRANCH="origin/1.x"
rest_utils_BRANCH="origin/1.x"
schema_registry_BRANCH="origin/1.x"


###
### Enabling/disabling tests
###
#
# Set SKIP_TESTS to "yes" to disable tests, to "no" to enable tests.
SKIP_TESTS="no"

# Overrides for specific projects.  Use project_name_using_underscores_SKIP_TESTS.
#
# Override examples:
# ------------------
# kafka_rest_SKIP_TESTS="yes"
#
camus_SKIP_TESTS="yes" # We do not run tests for Camus.
