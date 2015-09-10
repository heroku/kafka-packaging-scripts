#!/usr/bin/env bats
#
# This test suite verifies the correctness of generated *packages*.
# It is run on your host machine, i.e. it is not run in the build VMs.
#
# This test suite is concerned about e.g. correct package metata (such as RPM
# correct 'Version' and 'Release' fields) and whether all required packages were
# actually built.  This test suite does not, however, verify the actual
# *contents* of the packages (e.g. "Can we start a Kafka broker successfully
# after the Kafka RPM was installed?"); this latter type of verification is
# covered by `test.sh`.
#
# Requirements
# ------------
# Your host machine must have `bats` (https://github.com/sstephenson/bats)
# as well as `dpkg` and `rpm` installed.
#

. settings.sh
. versioning_helpers.sh

# TODO: Verify exact version label in filenames instead of broad regex matching.

# Test settings
CONFLUENT_PACKAGE_PREFIX="confluent"
STAT_MAC_OPTS_FOR_FILESIZE="-f%z"


@test "archive packages (tar base) were built" {
  for pkg in $CP_PACKAGES kafka; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.tar\.gz$\""
    [ "$status" -eq 0 ]
  done
}

@test "archive packages (tar base) have a certain minimum file size (heuristic to detect broken packages)" {
  for pkg in $CP_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.tar\.gz$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done
}

@test "archive packages (tar orig/debian) were built" {
  for pkg in $CP_PACKAGES kafka platform; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}_[0-9a-zA-Z\.~-]+\.(orig|debian)\.tar\.gz$\""
    [ "$status" -eq 0 ]
  done
}

@test "archive packages (zip) were built" {
  for pkg in $CP_PACKAGES kafka; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.zip$\""
    [ "$status" -eq 0 ]
  done
  run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-[0-9a-zA-Z\.~-]+\.zip$\""
  [ "$status" -eq 0 ]
}

@test "archive packages (zip) have a certain minimum file size (heuristic to detect broken packages)" {
  for pkg in $CP_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.zip$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done
  for file in `s $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-[0-9a-zA-Z\.~-]+\.zip$"`; do
    run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
    local filesize=$(($output + 0))
    [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
  done
}

@test "deb packages were built" {
  for pkg in $CP_PACKAGES; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}_[0-9a-zA-Z\.~-]+_all\.deb$\""
    [ "$status" -eq 0 ]
  done
  # Packages that include Scala version identifiers
  for pkg in kafka platform; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9\.]+_[0-9a-zA-Z\.~-]+_all\.deb$\""
    [ "$status" -eq 0 ]
  done
}

@test "deb metadata has correct version field" {
  for pkg in $CP_PACKAGES; do
    local deb_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-${pkg}[-_]*.deb"
    actual_version_field="$(dpkg -f $deb_file_pattern | grep '^Version' | sed -E 's/^Version: (.+)$/\1/')"
    expected_version_field=`deb_version_field $CONFLUENT_VERSION $REVISION`
    [ "$actual_version_field" = "$expected_version_field" ]
  done

  # Kafka
  for scala_version in $SCALA_VERSIONS; do
    local deb_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-kafka-${scala_version}_*.deb"
    actual_version_field="$(dpkg -f $deb_file_pattern | grep '^Version' | sed -E 's/^Version: (.+)$/\1/')"
    expected_version_field=`deb_version_field $KAFKA_VERSION $REVISION`
    [ "$actual_version_field" = "$expected_version_field" ]
  done

  # Platform
  for scala_version in $SCALA_VERSIONS; do
    local deb_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-platform-${scala_version}_*.deb"
    actual_version_field="$(dpkg -f $deb_file_pattern | grep '^Version' | sed -E 's/^Version: (.+)$/\1/')"
    expected_version_field=`deb_version_field $CONFLUENT_VERSION $REVISION`
    [ "$actual_version_field" = "$expected_version_field" ]
  done
}

@test "deb packages have a certain minimum file size (heuristic to detect broken packages)" {
  # We do not check for `confluent-platform` packages as these are expected to be only a few KB in size.
  for pkg in $CP_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}_[0-9a-zA-Z\.~-]+_all\.deb$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done
}

@test "rpm packages were built" {
  for pkg in $CP_PACKAGES kafka platform; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.noarch\.rpm$\""
    [ "$status" -eq 0 ]
  done
}

@test "rpm metadata has correct version+release fields" {
  for pkg in $CP_PACKAGES; do
    local rpm_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-${pkg}[-_]*.rpm"
    actual_version_field="$(rpm -qpi $rpm_file_pattern | grep '^Version' | sed -E 's/^Version[[:space:]]+: (.+)[[:space:]]+Vendor:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_version_field=`rpm_version_field $CONFLUENT_VERSION`
    actual_release_field="$(rpm -qpi $rpm_file_pattern | grep '^Release' | sed -E 's/^Release[[:space:]]+: (.+)[[:space:]]+Build Date:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_release_field=`rpm_release_field $CONFLUENT_VERSION $REVISION`
    [ "$actual_version_field" = "$expected_version_field" ]
    [ "$actual_release_field" = "$expected_release_field" ]
  done

  # Kafka
  for scala_version in $SCALA_VERSIONS; do
    local rpm_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-kafka-${scala_version}-*.rpm"
    actual_version_field="$(rpm -qpi $rpm_file_pattern | grep '^Version' | sed -E 's/^Version[[:space:]]+: (.+)[[:space:]]+Vendor:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_version_field=`rpm_version_field $KAFKA_VERSION $REVISION`
    actual_release_field="$(rpm -qpi $rpm_file_pattern | grep '^Release' | sed -E 's/^Release[[:space:]]+: (.+)[[:space:]]+Build Date:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_release_field=`rpm_release_field $KAFKA_VERSION $REVISION`
    [ "$actual_version_field" = "$expected_version_field" ]
    [ "$actual_release_field" = "$expected_release_field" ]
  done

  # Platform
  for scala_version in $SCALA_VERSIONS; do
    local rpm_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-platform-${scala_version}-*.rpm"
    actual_version_field="$(rpm -qpi $rpm_file_pattern | grep '^Version' | sed -E 's/^Version[[:space:]]+: (.+)[[:space:]]+Vendor:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_version_field=`rpm_version_field $CONFLUENT_VERSION $REVISION`
    actual_release_field="$(rpm -qpi $rpm_file_pattern | grep '^Release' | sed -E 's/^Release[[:space:]]+: (.+)[[:space:]]+Build Date:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_release_field=`rpm_release_field $CONFLUENT_VERSION $REVISION`
    [ "$actual_version_field" = "$expected_version_field" ]
    [ "$actual_release_field" = "$expected_release_field" ]
  done
}

@test "rpm packages have a certain minimum file size (heuristic to detect broken packages)" {
  # We do not check for `confluent-platform` packages as these are expected to be only a few KB in size.
  for pkg in $CP_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.noarch\.rpm$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done
}
