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
#
# Development tips
# ----------------
# * Tests can be skipped by using the `skip` command at the point in a test you wish to skip.
#   Optionally, you may include a reason for skipping (e.g. `skip "unreliable on Mac OS 10.10"`)
#   Details at https://github.com/sstephenson/bats#skip-easily-skip-tests.
#

. settings.sh
. versioning_helpers.sh

# TODO: Verify exact version label in filenames instead of broad regex matching.

# Test settings
CONFLUENT_PACKAGE_PREFIX="confluent"
STAT_MAC_OPTS_FOR_FILESIZE="-f%z"

contains() {
  local space_separated_list="$1"
  local entry="$2"
  if [[ $space_separated_list =~ (^| )$entry($| ) ]]; then
    return 0
  else
    return 1
  fi
}

is_c_package() {
  local list="$C_PACKAGES"
  retval=`contains $list $1`
  return $retval
}

@test "archive packages (tar base) were built" {
  for pkg in $JAVA_PACKAGES kafka; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.tar\.gz$\""
    [ "$status" -eq 0 ]
  done

  for pkg in $C_PACKAGES; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}-[0-9\.]+_${CONFLUENT_VERSION}\.tar\.gz$\""
    [ "$status" -eq 0 ]
  done
}

@test "archive packages (tar base) have a certain minimum file size (heuristic to detect broken packages)" {
  for pkg in $JAVA_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.tar\.gz$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done

  for pkg in $C_PACKAGES; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${pkg}-[0-9\.]+_${CONFLUENT_VERSION}\.tar\.gz$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done
}

@test "archive platform packages (aggregated tar) contain all individual packages (heuristic to detect broken packages)" {
  for scala_version in $SCALA_VERSIONS; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}-${scala_version}\.tar\.gz$"`; do
      paths=`tar -tzf $OUTPUT_DIRECTORY/$file`

      for pkg in $JAVA_PACKAGES kafka; do
        local pkg_dir="$pkg"
        if [ "$pkg" = "common" ]; then
          pkg_dir="${CONFLUENT_PACKAGE_PREFIX}-common"
        fi
        local found_a_jar=0
        for path in $paths; do
          if [[ "$path" == *${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}/share/java/${pkg_dir}/*.jar ]]; then
            found_a_jar=1
            break
          fi
        done
        [ "$found_a_jar" -eq 1 ]
      done

      for pkg in $C_PACKAGES; do
        local found_src_tarball=0
        for path in $paths; do
          if [[ "$path" == *${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}/src/$pkg-*_${CONFLUENT_VERSION}.tar.gz ]]; then
            found_src_tarball=1
            break
          fi
        done
        [ "$found_src_tarball" -eq 1 ]
      done
    done
  done
}

@test "archive packages (tar orig/debian) were built" {
  for pkg in $JAVA_PACKAGES kafka platform; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}_[0-9a-zA-Z\.~-]+\.(orig|debian)\.tar\.gz$\""
    [ "$status" -eq 0 ]
  done

  for pkg in $C_PACKAGES; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}_[0-9a-zA-Z\.~-]+\.(orig|debian)\.tar\.gz$\""
    [ "$status" -eq 0 ]
  done
}

@test "archive platform packages (tar for debs) contain all individual packages (heuristic to detect broken packages)" {
  version_token=`deb_version_field $CONFLUENT_VERSION $REVISION`
  for scala_version in $SCALA_VERSIONS; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}-${scala_version}-deb\.tar\.gz$"`; do
      paths=`tar -tzf $OUTPUT_DIRECTORY/$file`
      for pkg in $JAVA_PACKAGES; do
        local found=0
        for path in $paths; do
          if [[ "$path" == */${CONFLUENT_PACKAGE_PREFIX}-${pkg}_${version_token}_all.deb ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
      done

      # Kafka
      local found=0
      for path in $paths; do
        if [[ "$path" == */${CONFLUENT_PACKAGE_PREFIX}-kafka-${scala_version}_${KAFKA_VERSION}-${REVISION}_all.deb ]]; then
          found=1
          break
        fi
      done
      [ "$found" -eq 1 ]

      for pkg in $C_PACKAGES; do
        # e.g. librdkafka1
        local found=0
        for path in $paths; do
          if [[ "$path" == */${pkg}1_*1confluent${version_token}_amd64.deb ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
        # e.g. librdkafka-dev
        local found=0
        for path in $paths; do
          if [[ "$path" == */${pkg}-dev_*1confluent${version_token}_amd64.deb ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
        # e.g. librdkafka1-dbg
        local found=0
        for path in $paths; do
          if [[ "$path" == */${pkg}1-dbg_*1confluent${version_token}_amd64.deb ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
      done
    done
  done
}

@test "archive platform packages (tar for rpms) contain all individual packages (heuristic to detect broken packages)" {
  version_token=`rpm_version $CONFLUENT_VERSION`
  revision_token=`rpm_release_field $CONFLUENT_VERSION $REVISION`
  full_token="${version_token}-${revision_token}"
  for scala_version in $SCALA_VERSIONS; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}-${scala_version}-rpm\.tar\.gz$"`; do
      paths=`tar -tzf $OUTPUT_DIRECTORY/$file`
      for pkg in $JAVA_PACKAGES; do
        local found=0
        for path in $paths; do
          if [[ "$path" == */${CONFLUENT_PACKAGE_PREFIX}-${pkg}-${full_token}.noarch.rpm ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
      done

      # Kafka
      local found=0
      for path in $paths; do
        if [[ "$path" == */${CONFLUENT_PACKAGE_PREFIX}-kafka-${scala_version}-${KAFKA_VERSION}-${REVISION}.noarch.rpm ]]; then
          found=1
          break
        fi
      done
      [ "$found" -eq 1 ]

      for pkg in $C_PACKAGES; do
        # e.g. librdkafka1
        local found=0
        for path in $paths; do
          if [[ "$path" == */${pkg}1-*_confluent${full_token}.fc[0-9][0-9].x86_64.rpm ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
        # e.g. librdkafka (src)
        local found=0
        for path in $paths; do
          if [[ "$path" == */${pkg}-*_confluent${full_token}.fc[0-9][0-9].src.rpm ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
        # e.g. librdkafka-devel
        local found=0
        for path in $paths; do
          if [[ "$path" == */${pkg}-devel-*_confluent${full_token}.fc[0-9][0-9].x86_64.rpm ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
        # e.g. librdkafka-debuginfo
        local found=0
        for path in $paths; do
          if [[ "$path" == */${pkg}-debuginfo-*_confluent${full_token}.fc[0-9][0-9].x86_64.rpm ]]; then
            found=1
            break
          fi
        done
        [ "$found" -eq 1 ]
      done
    done
  done
}

@test "archive packages (zip) were built" {
  for pkg in $JAVA_PACKAGES kafka; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.zip$\""
    [ "$status" -eq 0 ]
  done

  for pkg in $C_PACKAGES; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}-[0-9\.]+_[0-9a-zA-Z\.~-]+\.zip$\""
    [ "$status" -eq 0 ]
  done

  run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-[0-9a-zA-Z\.~-]+\.zip$\""
  [ "$status" -eq 0 ]
}

@test "archive packages (zip) have a certain minimum file size (heuristic to detect broken packages)" {
  for pkg in $JAVA_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.zip$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done

  for pkg in $C_PACKAGES; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${pkg}-[0-9a-zA-Z\.~-]+_${CONFLUENT_VERSION}\.zip$"`; do
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

@test "archive platform packages (aggregated zip) contain all individual packages (heuristic to detect broken packages)" {
  for scala_version in $SCALA_VERSIONS; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}-${scala_version}\.zip$"`; do
      paths=`unzip -l $OUTPUT_DIRECTORY/$file | awk '{ print $4 }'| grep "^confluent-" `

      for pkg in $JAVA_PACKAGES kafka; do
        local pkg_dir="$pkg"
        if [ "$pkg" = "common" ]; then
          pkg_dir="${CONFLUENT_PACKAGE_PREFIX}-common"
        fi
        local found_a_jar=0
        for path in $paths; do
          if [[ "$path" == ${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}/share/java/${pkg_dir}/*.jar ]]; then
            found_a_jar=1
            break
          fi
        done
        [ "$found_a_jar" -eq 1 ]
      done

      for pkg in $C_PACKAGES; do
        local found_src_tarball=0
        for path in $paths; do
          if [[ "$path" == *${CONFLUENT_PACKAGE_PREFIX}-${CONFLUENT_VERSION}/src/$pkg-*_${CONFLUENT_VERSION}.zip ]]; then
            found_src_tarball=1
            break
          fi
        done
        [ "$found_src_tarball" -eq 1 ]
      done
    done
  done
}

@test "deb packages were built" {
  version_token=`deb_version_field $CONFLUENT_VERSION $REVISION`
  for pkg in $JAVA_PACKAGES; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}_${version_token}_all\.deb$\""
    [ "$status" -eq 0 ]
  done

  for pkg in $C_PACKAGES; do
    # e.g. librdkafka1
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}1_[0-9\.]+~1confluent${version_token}_amd64\.deb$\""
    [ "$status" -eq 0 ]
    # e.g. librdkafka-dev
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}-dev_[0-9\.]+~1confluent${version_token}_amd64\.deb$\""
    [ "$status" -eq 0 ]
    # e.g. librdkafka1-dbg
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}1-dbg_[0-9\.]+~1confluent${version_token}_amd64\.deb$\""
    [ "$status" -eq 0 ]
  done

  # Packages that include Scala version identifiers
  for pkg in kafka platform; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9\.]+_[0-9a-zA-Z\.~-]+_all\.deb$\""
    [ "$status" -eq 0 ]
  done
}

@test "deb metadata has correct version field" {
  version_token=`deb_version_field $CONFLUENT_VERSION $REVISION`
  for pkg in $JAVA_PACKAGES; do
    local deb_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-${pkg}[-_]*.deb"
    actual_version_field="$(dpkg -f $deb_file_pattern | grep '^Version' | sed -E 's/^Version: (.+)$/\1/')"
    [ "$actual_version_field" = "$version_token" ]
  done

  for pkg in $C_PACKAGES; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${pkg}(1|1-dbg|-dev)_[0-9\.]+~1confluent${version_token}_amd64\.deb$"`; do
      actual_version_field="$(dpkg -f $OUTPUT_DIRECTORY/$file | grep '^Version' | sed -E 's/^Version: (.+)$/\1/')"
      [ $(expr "$actual_version_field" : "^[0-9][0-9\.]*~1confluent${version_token}$") -ne 0 ]
    done
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
    [ "$actual_version_field" = "$version_token" ]
  done
}

@test "deb packages have a certain minimum file size (heuristic to detect broken packages)" {
  # We do not check for `confluent-platform` packages as these are expected to be only a few KB in size.
  version_token=`deb_version_field $CONFLUENT_VERSION $REVISION`
  for pkg in $JAVA_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}_[0-9a-zA-Z\.~-]+_all\.deb$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done

  for pkg in $C_PACKAGES; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${pkg}(1|1-dbg|-dev)_[0-9\.]+~1confluent${version_token}_amd64\.deb$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done
}

@test "rpm packages were built" {
  version_token=`rpm_version $CONFLUENT_VERSION`
  revision_token=`rpm_release_field $CONFLUENT_VERSION $REVISION`
  full_token="${version_token}-${revision_token}"

  for pkg in $JAVA_PACKAGES kafka platform; do
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.noarch\.rpm$\""
    [ "$status" -eq 0 ]
  done

  for pkg in $C_PACKAGES; do
    # e.g. librdkafka1
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}1-[0-9\.]+_confluent${full_token}\.fc[0-9]+\.x86_64\.rpm$\""
    [ "$status" -eq 0 ]
    # e.g. librdkafka1 (src)
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}-[0-9\.]+_confluent${full_token}\.fc[0-9]+\.src\.rpm$\""
    [ "$status" -eq 0 ]
    # e.g. librdkafka-devel
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}-devel-[0-9\.]+_confluent${full_token}\.fc[0-9]+\.x86_64\.rpm$\""
    [ "$status" -eq 0 ]
    # e.g. librdkafka1-debuginfo
    run bash -c "ls $OUTPUT_DIRECTORY/ | egrep \"^${pkg}-debuginfo-[0-9\.]+_confluent${full_token}\.fc[0-9]+\.x86_64\.rpm$\""
    [ "$status" -eq 0 ]
  done
}

@test "rpm metadata has correct version+release fields" {
  version_token=`rpm_version $CONFLUENT_VERSION`
  revision_token=`rpm_release_field $CONFLUENT_VERSION $REVISION`
  full_token="${version_token}-${revision_token}"

  for pkg in $JAVA_PACKAGES; do
    local rpm_file_pattern="${OUTPUT_DIRECTORY}/${CONFLUENT_PACKAGE_PREFIX}-${pkg}[-_]*.rpm"
    actual_version_field="$(rpm -qpi $rpm_file_pattern | grep '^Version' | sed -E 's/^Version[[:space:]]+: (.+)[[:space:]]+Vendor:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_version_field=`rpm_version_field $CONFLUENT_VERSION`
    actual_release_field="$(rpm -qpi $rpm_file_pattern | grep '^Release' | sed -E 's/^Release[[:space:]]+: (.+)[[:space:]]+Build Date:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
    expected_release_field=`rpm_release_field $CONFLUENT_VERSION $REVISION`
    [ "$actual_version_field" = "$expected_version_field" ]
    [ "$actual_release_field" = "$expected_release_field" ]
  done

  for pkg in $C_PACKAGES; do
    local num_variants=0
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${pkg}(1|-debuginfo|-devel|\b)-[0-9\.]+_confluent${full_token}\.fc[0-9]+\.(x86_64|src)\.rpm$"`; do
      num_variants=$((num_variants + 1))
      actual_version_field="$(rpm -qpi $OUTPUT_DIRECTORY/$file | grep '^Version' | sed -E 's/^Version[[:space:]]+: (.+)[[:space:]]+Vendor:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
      [ $(expr "$actual_version_field" : "^[0-9][0-9\.]*_confluent${version_token}$") -ne 0 ]

      actual_release_field="$(rpm -qpi $OUTPUT_DIRECTORY/$file | grep '^Release' | sed -E 's/^Release[[:space:]]+: (.+)[[:space:]]+Build Date:.*$/\1/' | sed -e 's/[[:space:]]*$//')"
      [ $(expr "$actual_release_field" : "^${revision_token}\.fc[0-9][0-9]$") -ne 0 ]
    done
    [ "$num_variants" -eq 4 ]
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
  version_token=`rpm_version $CONFLUENT_VERSION`
  revision_token=`rpm_release_field $CONFLUENT_VERSION $REVISION`
  full_token="${version_token}-${revision_token}"

  for pkg in $JAVA_PACKAGES kafka; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${CONFLUENT_PACKAGE_PREFIX}-${pkg}-[0-9a-zA-Z\.~-]+\.noarch\.rpm$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done

  for pkg in $C_PACKAGES; do
    for file in `ls $OUTPUT_DIRECTORY/ | egrep "^${pkg}(1|-debuginfo|-devel|\b)-[0-9\.]+_confluent${full_token}\.fc[0-9]+\.(x86_64|src)\.rpm$"`; do
      run stat $STAT_MAC_OPTS_FOR_FILESIZE $OUTPUT_DIRECTORY/$file
      local filesize=$(($output + 0))
      [ "$filesize" -ge $PACKAGE_MIN_FILE_SIZE_BYTES ]
    done
  done

}
