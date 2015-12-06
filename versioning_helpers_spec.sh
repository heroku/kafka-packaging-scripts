#!/usr/bin/env bats
#
# Requirements for running this test suite
# ----------------------------------------
# Your host machine must have `bats` (https://github.com/sstephenson/bats) installed.

. versioning_helpers.sh

# TODO: Increase test coverage of functions in versioning_helpers.sh.

@test "extract major.minor version from full version" {
  result="$(rpm_version_major_minor 1)"
  [ "$result" = "1" ]
  result="$(rpm_version_major_minor 1.)"
  [ "$result" = "1" ]
  for version in 1.0 1.0-alpha 1.0-beta2 1.0.2 1.0.1-SNAPSHOT; do
    result="$(rpm_version_major_minor $version)"
    [ "$result" = "1.0" ]
  done
}

@test "extract version from full version" {
  result="$(rpm_version 1)"
  [ "$result" = "1" ]
  result="$(rpm_version 1.)"
  [ "$result" = "1." ]
  for version in 1.0 1.0-alpha 1.0-beta2; do
    result="$(rpm_version $version)"
    [ "$result" = "1.0" ]
  done
  for version in 1.0.2 1.0.2-SNAPSHOT; do
    result="$(rpm_version $version)"
    [ "$result" = "1.0.2" ]
  done
}

@test "extract CP x.y.z release number from a version-indexed S3 bucket name" {
  result="$(cp_release_from_versioned_s3_bucket staging-confluent-packages-1.2.3)"
  [ "$result" = "1.2.3" ]
  result="$(cp_release_from_versioned_s3_bucket confluent-packages-2.0.0)"
  [ "$result" = "2.0.0" ]
}

@test "extract CP repository release sub-directory from a version-indexed S3 bucket name" {
  result="$(repo_release_subdir_from_versioned_s3_bucket staging-confluent-packages-1.2.3)"
  [ "$result" = "1.2" ]
  result="$(repo_release_subdir_from_versioned_s3_bucket confluent-packages-2.0.0)"
  [ "$result" = "2.0" ]
}

@test "compare two version strings" {
  result="$(version_compare 1 1)"
  [ "$result" = "0" ]
  result="$(version_compare 1.0 1.0)"
  [ "$result" = "0" ]
  result="$(version_compare 1 1.0)"
  [ "$result" = "0" ]
  result="$(version_compare 1 1.0.0)"
  [ "$result" = "0" ]
  result="$(version_compare 1.0.0 1)"
  [ "$result" = "0" ]
  result="$(version_compare 1.0 1)"
  [ "$result" = "0" ]
  result="$(version_compare 2.3 2.3.0)"
  [ "$result" = "0" ]
  result="$(version_compare 2.3.0 2.3)"
  [ "$result" = "0" ]
  result="$(version_compare 1.0 1.0.0)"
  [ "$result" = "0" ]
  result="$(version_compare 1.0 1.0.1)"
  [ "$result" = "1" ]
  result="$(version_compare 1.0.0 1.0.0)"
  [ "$result" = "0" ]
  result="$(version_compare 1.0.0 1.0.1)"
  [ "$result" = "1" ]
  result="$(version_compare 1.0.1 1.0.0)"
  [ "$result" = "2" ]
  result="$(version_compare 1.0.0 2.0.0)"
  [ "$result" = "1" ]
  result="$(version_compare 2.0.0 1.0.0)"
  [ "$result" = "2" ]
  result="$(version_compare 1.3.0 2.0.0)"
  [ "$result" = "1" ]
  result="$(version_compare 2.0.0 1.3.0)"
  [ "$result" = "2" ]
  result="$(version_compare 2.3.5 2.3.4)"
  [ "$result" = "2" ]
  result="$(version_compare 2.3 2.3.1)"
  [ "$result" = "1" ]
  result="$(version_compare 2.3.1 2.3)"
  [ "$result" = "2" ]
}

@test "generate debian Version field for normal CP packages" {
  result="$(deb_version_field 2.0.0 1)"
  [ "$result" = "2.0.0-1" ]
  result="$(deb_version_field 2.0.0 3)"
  [ "$result" = "2.0.0-3" ]
  result="$(deb_version_field 2.0.0-SNAPSHOT 1)"
  [ "$result" = "2.0.0~SNAPSHOT-1" ]
  result="$(deb_version_field 2.0.0-SNAPSHOT 3)"
  [ "$result" = "2.0.0~SNAPSHOT-3" ]
  result="$(deb_version_field 1.2.3 1)"
  [ "$result" = "1.2.3-1" ]
  result="$(deb_version_field 1.2.3 4)"
  [ "$result" = "1.2.3-4" ]
}

@test "generate debian Version field for librdkafka" {
  result="$(deb_version_field_librdkafka 0.9.0 2.0.0 1)"
  [ "$result" = "0.9.0~1confluent2.0.0-1" ]
  result="$(deb_version_field_librdkafka 0.9.0 2.0.0 3)"
  [ "$result" = "0.9.0~1confluent2.0.0-3" ]
  result="$(deb_version_field_librdkafka 0.9.0 2.0.0-SNAPSHOT 1)"
  [ "$result" = "0.9.0~1confluent2.0.0~SNAPSHOT-1" ]
  result="$(deb_version_field_librdkafka 0.9.0 2.0.0-SNAPSHOT 3)"
  [ "$result" = "0.9.0~1confluent2.0.0~SNAPSHOT-3" ]
  result="$(deb_version_field_librdkafka 7.8.9 1.2.3 1)"
  [ "$result" = "7.8.9~1confluent1.2.3-1" ]
  result="$(deb_version_field_librdkafka 7.8.9 1.2.3 4)"
  [ "$result" = "7.8.9~1confluent1.2.3-4" ]
}

@test "generate rpm Version field for librdkafka" {
  result="$(rpm_version_field_librdkafka 0.9.0 2.0.0)"
  [ "$result" = "0.9.0_confluent2.0.0" ]
  result="$(rpm_version_field_librdkafka 0.9.0 2.0.0-SNAPSHOT)"
  [ "$result" = "0.9.0_confluent2.0.0" ]
  result="$(rpm_version_field_librdkafka 7.8.9 1.2.3)"
  [ "$result" = "7.8.9_confluent1.2.3" ]
}

@test "generate rpm Release field for librdkafka" {
  result="$(rpm_release_field_librdkafka 2.0.0 1)"
  [ "$result" = "1.fc20" ]
  result="$(rpm_release_field_librdkafka 2.0.0 3)"
  [ "$result" = "3.fc20" ]
  result="$(rpm_release_field_librdkafka 2.0.0-SNAPSHOT 1)"
  [ "$result" = "0.1.SNAPSHOT.fc20" ]
  result="$(rpm_release_field_librdkafka 2.3.4-SNAPSHOT 5)"
  [ "$result" = "0.5.SNAPSHOT.fc20" ]
  result="$(rpm_release_field_librdkafka 1.2.3 1)"
  [ "$result" = "1.fc20" ]
  result="$(rpm_release_field_librdkafka 1.2.3 4)"
  [ "$result" = "4.fc20" ]
}
