Confluent Packaging
-------------------

This repository contains scripts to build all the binary packages for
Confluent's distribution. It:

* Builds in clean VMs to ensure reproducible builds.
* Handles dependencies, i.e. makes sure that kafka-rest's build process has
  access to a compiled version of rest-utils, even if rest-utils isn't available
  publicly (e.g. via Central).
* Ties together all the standalone tgz/zip archives into one large distribution.
* Does a basic installation sanity check on the resulting packages.


Usage
-----

```shell
# One-time setup: make sure you've generated GPG keys that you'll sign
# packages with. It's easy to find instructions online. You can check that
# you have the secret key installed in your home directory on the host:
$ gpg --list-secret-keys
/Users/ewencp/.gnupg/secring.gpg
--------------------------------
sec   4096R/BE7EFC73 2015-01-14
uid                  Ewen Cheslack-Postava <ewen@confluent.io>
ssb   4096R/08EA97A4 2015-01-14
# This will be installed in the VMs automatically.
#
# You'll also need AWS CLI and Aptly for deploying artifacts
$ brew install awscli aptly

# Create VMs for the scripts to work with. You'll get 'rpm' and 'deb'
# VMs. We just reuse the 'rpm' one for generating generic archives since
# that's essentially a subset of generating the RPMs.
$ vagrant up

# Run the packaging. This takes care of all projects and package
# types. Assuming everything works, you'll find the output in output/.
# This step depends on some settings which are specificed in versions.sh,
# which is sourced into package.sh:
#   CONFLUENT_VERSION - Version of Confluent's tools
#   KAFKA_VERSION - Apache Kafka version to build against
#   SCALA_VERSIONS - list of Scala versions to use for Scala-dependent
#                    projects. These should just be extracted from the Kafka
#                    build scripts.
#   BRANCH - for testing/debug, setting this will override the branch/tag we
#            merge with for each (non-Kafka) project. This lets you specify,
#            e.g., "origin/master" to test against the latest, untagged
#            version of all the projects to get SNAPSHOT builds.
#   SIGN - If "yes" (the default), sign packages with your GPG key. You'll
#          probably want to turn this off while testing since it is the only
#          step that can't be automated -- you are required to manually
#          enter your GPG key password for every package.
#   SIGN_KEY - The name (e.g. "Ewen Cheslack-Postava <ewen@confluent.io>")
#          of the GPG key to sign with. This currently *MUST* also be your
#          default key (which will be the case if you have only one secret
#          key) because of differences in how RPM and deb signing work. If
#          left empty, we'll try to fill it in automatically using `gpg
#          --list-secret-keys`
# Note that we don't currently have per-project overrides, so the assumption
# here is that all projects make version updates in lock-step.
#
# Also note that we don't support building single packages. There's not much
# point since you need to build the dependencies as well so they'll be
# available during the mvn build process. If you're trying to get a new
# package added to package.sh and need to iterate quickly, let the
# dependencies build once and then comment them out temporarily.
$ ./package.sh

# See all the generated output files.
$ ls output/

# We don't want to keep a complete test suite here, but it's good to have at
# least some baseline sanity checks that the packages we produce actually
# work. The test script tries to install packages and run some key programs.
$ ./test.sh
# If something went wrong with the tests, it'll print out a big, obvious
# error message.

# Now we need to actually deploy the resulting archives. We need to do this
# in a number of formats: archives, rpm, deb, and deploy jars into a Maven
# repository. We'll store all our repositories in S3, so we'll start by
# configuring S3 credentials. Make a copy of the template and fill in your
# credentials and bucket info:
$ cp aws.sh.template aws.sh
$ emacs aws.sh
# Note that this file is ignored by git so you won't accidentally check it
# in. Note that if you're setting up your own S3 bucket for testing, this
# script assumes that there is an ACL policy on the bucket that makes
# everything readable anonymously. You can add a prefix if you don't want to
# install to the root of the bucket -- just make sure it includes the
# leading /.

# Next, make sure you are now switched to JDK 7. During deployment, we
# re-build to generate the Maven output, but we use the S3 Maven Wagon to
# deploy, which requires JRE7. Where necessary, small patches are applied to
# ensure the output targets the correct Java 6 compatible version.
$ export JAVA_HOME=/path/to/jdk7

# Now we can run the deploy script.
# ##########################################################################
# WARNING: Not only will you be pushing artifacts to a public server, you
# can break things if you do this wrong. You *MUST* be working with a full
# copy of the existing data for some of these operations to work
# correctly. For example, if you don't have all the old RPMs, the index you
# generate will omit a bunch of files. Since you'll want to do a staging
# release before any final releases, you really need to be careful about
# being in sync with the existing repository for final releases.
# ##########################################################################
# Note that you'll be prompted multiple times for your GPG key password
# since some package index files are signed.
$ ./deploy.sh
# Note that the REVISION specified in versions.sh is important
# here. Packages go into repositories organized by CONFLUENT_VERSION. If we
# need to release any updates to packages, the REVISION needs to be bumped
# up so the packages go into the same repositories but are treated as
# updates to the existing packages.

# Finally, clean up the VMs. Except for the build output, the scripts should
# be careful to do everything in temporary space in the VM so your source
# tree doesn't get polluted with build by-products.
$ vagrant destroy
```

Adding New Packages
-------------------

The process of creating new packages is split between the original source
repository (for our software; use a secondary `X-packaging` repository for
third-party software) and this repository.

Assuming Java-only code (i.e. no Scala versioning, no JNI to native code),
generally you need to generate 3 packages:

1. tar.gz/zip
2. Debian
3. RPM

However, it's usually easiest to generate the tar.gz/zip in a reasonable layout
and then reuse that when generating the deb/rpm packages. Our packaging already
does this, so you can use it as a template.

Here's how we've generated our packages so far:

1. In the Maven project for the file, include some packaging scripts. See any of
   the repositories (e.g. [kafka-rest](https://github.com/confluentinc/kafka-rest/))
   for an example.
   * Usually `maven-assembly-plugin` is flexible enough to do this.
   * Layout should follow a standard Unix-y approach: most importantly, having
     `bin/` makes it clear how the user can get started running things. Normally
     jars go under `/usr/share/java/<project>`. Config files installed by the
     system normally go under `/etc`, there's no obvious place for them in
     tar/zip packages so we'll just use this same layout.
   * Include more than just the JARs -- licenses, READMEs, and wrapper bin
     scripts, should be included as well.
   * You'll need to be able to exclude dependencies that are packaged separately,
     and `maven-assembly-plugin` provides some support for this. For an
     example, see how [kafka-rest](https://github.com/confluentinc/kafka-rest/)
     filters out the `rest-utils` and its transitive dependencies in
     [src/assembly/package.xml](https://github.com/confluentinc/kafka-rest/blob/master/src/assembly/package.xml).
   * While you're at it, you might as well provide some other helpful packaging
     targets, e.g. an uber-jar and an in-tree development layout that matches the
     installed layout and allows simplified `bin/` scripts that work in both
     environments. There are examples of these in
     [kafka-rest](https://github.com/confluentinc/kafka-rest/).
2. Use one of the existing packages to bootstrap your packaging by pulling in
   the `archive`, `deb`, and `rpm` branches.
   * Make sure you pick a package with similar structure to yours
     (e.g. library vs. application, similar module layout since that can
     occasionally affect packaging). Then bootstrapping from the other repo is
     easy:

          cd myproject.git
          git remote add other /path/to/other.git
          git fetch other
          git checkout -b archive other/archive
          git checkout -b rpm other/rpm
          git checkout -b debian other/debian
          git remote remove other
   * If you are packaging a third party library, you may need to work in a
     separate repository. The process doesn't really differ much here -- you
     just add a step in the packaging script that pulls in the external code by
     merging it into your source tree. The only example we have of this so far
     is Kafka (see the `kafka-packaging` repository, but beware that those
     scripts are also different since they need to support multiple versions of
     Scala.
3. Customize these branches for your package.
   * 99% of the time you'll just need to customize package names and metadata.
   * Start with the `archive` branch since it is simplest and doesn't require
     any platform-specific knowledge. It's just a Makefile and helper script
     to get the files into the target layout.
   * For deb/rpm, make sure you rebase/cherry-pick against the updated
     `archive` branch, then update new files/sections of files (in particular
     the Makefile, spec files for RPM and the a few files under debian/ for
     debian. You'll need to work in VMs to get the build
     running. Unfortunately these are difficult to include in the repositories
     because of restrictions on what files can be included in the source tree
     when doing packaging. I suggest using Vagrant to pull up the VMs (a simple
     default Vagrantfile for the right OS should just work), then use the
     scripts under `build/` in this repository to understand the required
     sequence of commands. You'll want the Vagrantfile ***outside*** of your
     source tree. One easy way to do this is to use a Vagrantfile with two VMs
     (deb and rpm) one level higher than your checkout of the repository, so
     the repository is then (by default) available at /vagrant/<yourrepo> and
     Vagrant's files don't get in the way.
   * While developing, you'll use a separate branch to do the packaging. For
     example, we might do

          git checkout -b archive-0.1 archive

     to start `archive` packaging for `v0.1`. Then we merge in the code:

          git merge v0.1

     assuming `v0.1` is a tagged release. So each of these branches just
     maintains an *overlay* for packaging. Once we generate the package, we
     don't need the branch anymore and we can delete it.
   * We should rarely need patches for our own software, but even for our own
     the `debian` branches contain patches to add files that we don't want in
     the main repo, but that make the project friendlier to Debian
     packaging. This sometimes makes iterating a bit of a pain because some
     platforms, like Debian, require a completely clean source tree. You'll
     just have to get used to cleaning out extraneous files and using `git
     reset`.
4. Once you've got the packaging working for all platforms, make sure your
   branches are all pushed back to the central repo.
5. Add the package to this repository, which just drives packaging of all the
   individual packages and ties them all together.
   * If you have any extra system-level dependencies required during build
     (this is rare!), add them to the Vagrant bootstrapping scripts in
     `vagrant/`.
   * Add scripts for running the individual builds to `build/`. You probably
     just want to copy the scripts for the same package you used as a base for
     your `archive`, `rpm`, and `deb` branches and do some renaming as a
     start. Often this is all that's necessary, but we maintain separate scripts
     for separate packages to allow for easy customization where needed.
   * If necessary, add any version variables you need to `versions.sh`.
   * Add the package to the `package.sh` script. Key steps include: making sure
     your repo is in the `REPO` list to be cloned/updated; make sure it is
     included in the `PACKAGES` list (except for packages that can't just have
     their build scripts executed in the standard way); make sure any special
     concerns for compiling your package into the complete platform tar/zip
     files are addressed in the final sections of the script.
   * Add at least one simple test of your package to `test.sh`. You'll need to
     add install/uninstall lines for each platform, and then write a simple
     test to make sure your package works. These are not intended to test real
     functionality, just verify that the way you've packaged things up will allow
     them to work.
     For example, [kafka-rest](https://github.com/confluentinc/kafka-rest/) is
     tested without any other services running, so it can't do anything useful,
     but we are able to very that it started up without just quitting
     immediately.
   * Add the package to the `installers/install.sh` script, which is used when
     users download the full platform in deb or rpm format.
   * Test, fix up any issues, and commit.
