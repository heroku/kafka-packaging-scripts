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
