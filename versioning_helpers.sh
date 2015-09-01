### Versioning-related helper functions for testing.
### Imported by `package_verify.sh`.

# Return the RPM `Version` value from the provided full version.
#
# Usage
# -----
# rpm_version <full_version>
#
# Example
# -------
# rpm_version "1.0.1-SNAPSHOT" -> "1.0.1"
#
rpm_version() {
  local full_version=$1
  local rpm_ver=`echo $full_version | sed -e 's/-alpha[0-9]*//' -e 's/-beta[0-9]*//' -e 's/-rc[0-9]*//' -e 's/-SNAPSHOT//'`
  echo $rpm_ver
}

# Return any -alpha, -beta, -rc piece that we need to put into the `Release` field of the RPM metadata since RPM
# versions don't support non-numeric characters.
#
# Ultimately, for a non-final version like 0.8.2-beta, we want to end up with RPM_Version=0.8.2 RPM_Release=0.X.beta,
# where X is the REVISION (cf. settings.sh) of 0.8.2-beta.  The prefix `0.` forces this to be considered earlier than
# any 0.8.2 final releases since those will start with RPM_Version=0.8.2 RPM_Release=1.
#
# Usage
# -----
# rpm_release_postfix <full_version>
#
# Example
# -------
# rpm_release_postfix "1.0.1-SNAPSHOT" -> "SNAPSHOT"
#
rpm_release_postfix() {
  local full_version=$1
  local rpm_ver=`rpm_version $full_version`
  local rpm_release_postfix=${full_version#$rpm_ver}
  echo ${rpm_release_postfix#-}
}

# Returns true (0) if the provided full version is a final release, false (1) otherwise.
# Can be used directly in an if-statement.
#
# Usage
# -----
# is_final_release <full_version>
#
# Example
# -------
# if is_final_release "1.0.1-SNAPSHOT"; then
#   echo "Final release!"
# else
#   echo "Not a final release!"
# fi
#
#
is_final_release() {
  local full_version=$1
  local rpm_release_postfix=`rpm_release_postfix $full_version`
  if [ -n "$rpm_release_postfix" ]; then
    return 1
  else
    return 0
  fi
}

# Generate the value of the RPM "Version" field, given the full version,
# based on our naming policy for RPM metadata.
#
# Usage
# -----
# rpm_version_field <full_version>
#
# Examples
# --------
# rpm_version_field "1.0" --> "1.0"
# rpm_version_field "1.0.1-SNAPSHOT" --> "1.0.1"
rpm_version_field() {
  local full_version=$1
  local version_field=`rpm_version $full_version`
  echo $version_field
}

# Generate the value of the RPM "Release" field, given the full version,
# based on our naming policy for RPM metadata.
#
# Usage
# -----
# rpm_release_field <full_version> <revision>
#
# Examples
# --------
# rpm_release_field "1.0" "3" --> "3"
# rpm_release_field "1.0.1-SNAPSHOT" "3" --> "0.3.SNAPSHOT"
rpm_release_field() {
  local full_version=$1
  local revision_setting=$2
  local iteration="1" # Default "Release" setting for rpm if unspecified.
  if [ -n "$revision_setting" ]; then
    iteration=$revision_setting
  fi
  if is_final_release $full_version; then
    local release_field=$iteration
  else
    local release_prefix="0"
    local release_postfix=`rpm_release_postfix $full_version`
    local release_field="${release_prefix}.${iteration}.${release_postfix}"
  fi
  echo $release_field
}


# Generate the value of the Debian "Version" field, given the full version and
# the desired revision (cf. REVISION in settings.sh), based on our naming policy
# for Debian metadata.
#
# Usage
# -----
# deb_version_field <full_version> <revision>
#
# Examples
# --------
# deb_version_field "1.0" "3" --> "1.0-3"
# deb_version_field "1.0.1-SNAPSHOT" "3" --> "1.0.1~SNAPSHOT-3"
deb_version_field() {
  local full_version=$1
  local version_prefix=`rpm_version $full_version`
  local revision_setting=$2
  local iteration="1" # Default "Revision" setting for deb if unspecified.
  if [ -n "$revision_setting" ]; then
    iteration=$revision_setting
  fi
  if is_final_release $full_version; then
    local version_field="${version_prefix}-${iteration}"
  else
    local version_suffix=`rpm_release_postfix $full_version`
    local version_field="${version_prefix}~${version_suffix}-${iteration}"
  fi
  echo $version_field
}
