# Confluent Packaging

This repository contains scripts to build all the binary packages of the Confluent Platform.

* Builds in clean VMs to ensure reproducible builds.
* Handles dependencies, i.e. makes sure that kafka-rest's build process has
  access to a compiled version of
  [rest-utils](https://github.com/confluentinc/rest-utils), even if rest-utils
  isn't available publicly (e.g. via Central).
* Ties together all the standalone tgz/zip archives into one large distribution.
* Does a basic installation sanity check on the resulting packages.


---

Table of Contents

* <a href="#prerequisites">Prerequisites</a>
* <a href="#deploy">Building, testing, and deploying packages</a>
* <a href="#add-new">Adding new packages</a>
* <a href="#troubleshooting">Troubleshooting</a>

---

<a name="prerequisites"></a>

# Prerequisites

## Software packages on host machine

_This section covers Mac OS X only._

You must install the following software packages on your host machine (e.g. your laptop):

* [Vagrant](https://www.vagrantup.com/downloads.html) (1.7+ recommended)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (5.x+ recommended)

You'll also need AWS CLI and Aptly for deploying artifacts:

```shell
# `brew` is provided by Homebrew (http://brew.sh/)
$ brew install awscli aptly
```


## NFS for synced folders

_If you're running on Mac OS X then you should be ready to go out of the box._

Our [Vagrant setup](Vagrantfile) uses [NFS for synced folders](http://docs.vagrantup.com/v2/synced-folders/nfs.html)
because [it is faster than Vagrant's default](http://auramo.github.io/2014/12/vagrant-performance-tuning/).

However the use of NFS has the following extra requirements:

* Host:
    * The host (e.g. your laptop) must be running Mac OS X or Linux.  Windows lacks proper NFS support.
    * The host must have `nfsd` installed and running (default on Mac OS X).
    * Recommended: Ensure that any local firewall software on your host is not interfering with NFS.
* Guests aka VMs:
    * The guest must have NFS support installed (default for the `deb` and `rpm` Vagrant boxes we use).

Vagrant will also prompt you for **your sudo password** when you run commands such as `vagrant up` and
`vagrant destroy` because Vagrant must be able to update `/etc/exports` on your host machine.  (Your sudo password will
be cached for a certain amount of time.)


## GPG setup (for signing Confluent release packages)

Setting up GPG is generally a one-time task: Make sure you've access to our private GPG key that you'll sign Confluent
packages with.  You can check that you have the secret key installed in your home directory on the host (the output
of the command and thus the GPG key listed below is just an example):

```shell
# Your host machine, e.g. your laptop.
$ gpg --list-secret-keys
/Users/ewencp/.gnupg/secring.gpg
--------------------------------
sec   4096R/BE7EFC73 2015-01-14
uid                  Ewen Cheslack-Postava <ewen@confluent.io>
ssb   4096R/08EA97A4 2015-01-14
```

Your GPG setup on your host machine will automatically be installed in the VMs, too, thus making any GPG private
key(s) -- notably the private key we use for signing Confluent release packages -- available to the build process.


<a name="deploy"></a>

# Building, testing, and deploying packages

This section describes how to build, test, deploy, and thus release Confluent Platform packages.  Our current setup
makes use of Vagrant-powered local VMs to provide us with deterministic build environments.  Some steps will however
be run on your host machine, e.g. your laptop.

Here's a brief overview of the release process:

1. Launch the build VMs.
2. Configure the release process (e.g. version numbers).
3. Run the packaging build.
4. Run the smoke tests.
5. Deploy the packages.
6. Terminate the build VMs.


## Step 1: Launch the build VMs

Launch the VMs for the build scripts to work with, which are VirtualBox-powered VMs, managed via Vagrant.  You'll get
`rpm` and `deb` VMs.  We reuse the `rpm` VM for generating generic archives (`*.tar.gz` and `*.zip`) since that's
essentially a subset of generating the RPMs.

```shell
$ vagrant up
```


## Step 2: Configure the release process via `versions.sh`

Specify any required build and release settings in [versions.sh](versions.sh), which is sourced into
[package.sh](package.sh):

* `CONFLUENT_VERSION`:  Version of Confluent's tools.  Examples: `1.0` (a release), `1.0.1-SNAPSHOT`.
* `KAFKA_VERSION`:  Apache Kafka version to build against.  Example: `0.8.2.1`.
* `SCALA_VERSIONS`:  Space-separated list of Scala versions to use for Scala-dependent projects.  These should just be
  extracted from the Kafka build scripts.  Examples: `2.10.4`, `2.9.1 2.9.2 2.10.4 2.11.5`
* `REVISION`:  Packages go into yum/apt/... repositories organized by `CONFLUENT_VERSION`.  If we need to release any
  updates to packages, the `REVISION` needs to be bumped up so the packages go into the same repositories but are
  treated as updates to the existing packages.
* `BRANCH`:  For testing/debugging purposes, setting this will override the branch/tag we merge with for each
  (non-Kafka) project. For example, setting `BRANCH` to `origin/master` will build and test against the latest,
  untagged version of all the projects to get snapshot builds.  You can also provide project-specific overrides:

        BRANCH="origin/master"
        # Branch overrides for specific projects.  Use project_name_using_underscores_BRANCH.
        #
        # Examples:
        # ---------
        # camus_BRANCH="origin/confluent-master" # branch
        # kafka_rest_BRANCH="v1.0" # tag
        #
        kafka_rest_BRANCH="origin/1.x"

* `SKIP_TESTS`: If `yes` (default: `no`), do not run the test suites of the packages.  You can also provide
  project specific overrides:

        SKIP_TESTS="no"
        # Overrides for specific projects.  Use project_name_using_underscores_SKIP_TESTS.
        #
        # Examples:
        # ---------
        # kafka_rest_SKIP_TESTS="yes"
        #
        camus_SKIP_TESTS="yes" # We do not run tests for Camus.

* `SIGN`:  If `yes` (the default), sign packages with your GPG private key.  You'll probably want to turn this off
  by setting it to `no` while testing since it is the only step that can't be automated -- you are required to manually
  enter your GPG key password for every package, and GPG password prompts may timeout (thus cancelling/stopping the
  build process).
* `SIGN_KEY`:  The name (e.g. "Ewen Cheslack-Postava <ewen@confluent.io>") of the GPG key to sign with.  This currently
  *MUST* also be your default key (which will be the case if you have only one secret key) because of differences in
  how RPM and DEB signing work. If left empty, we'll try to fill it in automatically using `gpg --list-secret-keys`.

Note that we do not currently have per-project overrides for `VERSION`, so the assumption here is that all projects
make version updates in lock-step.


## Step 3: Run the packaging build

Running the packaging takes care of all projects and package types, based on the configuration you specified in
[versions.sh] (see previous section).  Assuming everything works, you'll find the generated packages in `output/`.

```shell
# For comparison, on a 2015 MacBook Pro 15" (2.5GHz Intel Core i7)
# the packaging of components as of August 2015 takes about one hour.
$ ./package.sh

# See all the generated output files.
$ ls output/
```

Example files for a build with `VERSION=1.0.1-SNAPSHOT`:

```
confluent-1.0.1-SNAPSHOT-2.10.4-deb.tar.gz
confluent-1.0.1-SNAPSHOT-2.10.4-rpm.tar.gz
confluent-1.0.1-SNAPSHOT-2.10.4.tar.gz
confluent-1.0.1-SNAPSHOT-2.10.4.zip
confluent-common-1.0.1-0.1.SNAPSHOT.noarch.rpm
confluent-common-1.0.1-SNAPSHOT.tar.gz
confluent-common-1.0.1-SNAPSHOT.zip
confluent-common_1.0.1~SNAPSHOT-1.debian.tar.gz
confluent-common_1.0.1~SNAPSHOT-1.dsc
confluent-common_1.0.1~SNAPSHOT-1_all.deb
confluent-common_1.0.1~SNAPSHOT-1_amd64.build
confluent-common_1.0.1~SNAPSHOT-1_amd64.changes
confluent-common_1.0.1~SNAPSHOT.orig.tar.gz
confluent-kafka-0.8.2.1-2.10.4.tar.gz
confluent-kafka-0.8.2.1-2.10.4.zip
confluent-kafka-2.10.4-0.8.2.1-1.noarch.rpm
confluent-kafka-2.10.4_0.8.2.1-1_all.deb
confluent-kafka-rest-1.0.1-0.1.SNAPSHOT.noarch.rpm
confluent-kafka-rest-1.0.1-SNAPSHOT.tar.gz
confluent-kafka-rest-1.0.1-SNAPSHOT.zip
[...]
```

Note that we don't support building single packages at the moment.  There's not much point since you need to build the
dependencies as well so they'll be available during the mvn build process. If you're trying to get a new package added
to [package.sh](package.sh) and need to iterate quickly, let the dependencies build once and then comment them out
temporarily in [package.sh](package.sh).


## Step 4: Run the smoke tests

We don't want to keep a complete test suite here, but it's good to have at least some baseline sanity checks that the
packages we produce actually work. The test script tries to install packages and run some key programs.

```shell
$ ./test.sh
```

If something went wrong with the tests, it'll print out a big, obvious error message.


## Step 5: Deploy the packages

Now we need to actually deploy the resulting packages and files in `output/`.  We need to do this in a number of
formats (archives, rpm, deb), and we also need to deploy jars into a Maven repository.  We'll store all our Confluent
repositories in S3, so we'll start by configuring S3 credentials.  Make a copy of the template
[aws.sh.template](aws.sh.template) and fill in your credentials and bucket info:

```shell
$ cp aws.sh.template aws.sh
$ vi aws.sh
```

The file `aws.sh` is ignored by git so you won't accidentally check it in and thereby leak your confidential AWS
credentials.

> **When testing deploying to S3:**  If you're setting up your own S3 bucket for testing, this script assumes that
> there is an ACL policy on the bucket that makes everything readable anonymously.  You can add a prefix if you don't
> want to install to the root of the bucket -- just make sure it includes the leading `/`.

Next, make sure you are now switched to Java 7.

> **Java 6 vs. Java 7**:  Future releases of the Confuent Platform will target Java 7.  The Java 6 related instructions
> in this README only apply to CP 1.x builds.

During deployment, we re-build to generate the Maven output, but we use the S3 Maven Wagon to deploy, which requires
JRE7.   Where necessary, small patches are applied to ensure the output targets the correct Java 6 compatible version.

```shell
# On a Mac you can use the `java_home` command:
#
# export JAVA_HOME=`/usr/libexec/java_home -v 1.6` # Java 6
# export JAVA_HOME=`/usr/libexec/java_home -v 1.7` # Java 7
#
$ export JAVA_HOME=/path/to/jdk7
```

Now we can run the deploy script.

> **IMPORTANT WARNING REGARDING DEPLOYMENTS**:  Not only will you be pushing artifacts to a public server, you can
> seriously break things if you do this wrong. You *MUST* be working with a full copy of the existing data for some
> of these operations to work correctly.  For example, if you don't have all the old RPMs, the index you generate
> will omit a bunch of files.  Since you'll want to do a staging release before any final releases, you really need
> to be careful about being in sync with the existing repository for final releases.

You will be prompted multiple times for your GPG key password since some package index files, which are generated
during this deployment step, will need to be signed.

Note that the `REVISION` specified in versions.sh is important here.  Packages go into repositories organized by
`CONFLUENT_VERSION`.  If we need to release any updates to packages, the `REVISION` needs to be bumped up so the
packages go into the same repositories but are treated as updates to the existing packages.

```shell
# Make sure you read the WARNING above before performing this step!
$ ./deploy.sh
```

At this point you have build, tested, and deployed the Confluent packages, which are now publicly available to
Confluent users.

## Step 6: Terminate the build VMs (clean up)

Finally, clean up the VMs.  Except for the build output under `output/`, the scripts should be careful to do
everything in temporary space in the VMs so your source tree doesn't get polluted with build by-products.

```shell
# Terminate the VMs
$ vagrant destroy
```


<a name="add-new"></a>

# Adding new packages

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
     filters out the [rest-utils](https://github.com/confluentinc/rest-utils)
     and its transitive dependencies in
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
     the Makefile, spec files for RPM and the a few files under `debian/` for
     debian). You'll need to work in VMs to get the build
     running. Unfortunately these are difficult to include in the repositories
     because of restrictions on what files can be included in the source tree
     when doing packaging. I suggest using Vagrant to pull up the VMs (a simple
     default Vagrantfile for the right OS should just work), then use the
     scripts under [build/](build/) in this repository to understand the required
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
   * Add scripts for running the individual builds to [build/](build/). You
     probably just want to copy the scripts for the same package you used as a
     base for your `archive`, `rpm`, and `deb` branches and do some renaming as a
     start. Often this is all that's necessary, but we maintain separate scripts
     for separate packages to allow for easy customization where needed.
   * If necessary, add any version variables you need to
     [versions.sh](versions.sh).
   * Add the package to the [package.sh](package.sh) script. Key steps include:
     1) make sure your repo is in the `REPO` list to be cloned/updated;
     2) make sure it is included in the `PACKAGES` list (except for packages
     that can't just have their build scripts executed in the standard way);
     3) make sure any special concerns for compiling your package into the
     complete platform tar/zip files are addressed in the final sections of the
     script.
   * Add at least one simple test of your package to [test.sh](test.sh).
     You'll need to add install/uninstall lines for each platform, and then
     write a simple test to make sure your package works. These are not intended
     to test real functionality, just verify that the way you've packaged things
     up will allow them to work.
     For example, [kafka-rest](https://github.com/confluentinc/kafka-rest/) is
     tested without any other services running, so it can't do anything useful,
     but we are able to verify that it started up without just quitting
     immediately.
   * Add the package to the
     [installers/install.sh](installers/install.sh) script, which is used when
     users download the full platform in deb or rpm format.
   * Test, fix up any issues, and commit.


<a name="troubleshooting"></a>

# Troubleshooting

## Synced folders do not work, Vagrant hangs at "Mounting NFS shared folders..."

Make sure you disable any local firewalls on your computer or add an appropriate whitelist entry while packaging,
otherwise you may run into problems working with NFS synced folders.

For example, the `vagrant up` command may hang at the point when it tries to mount NFS shares when a local firewall is
enabled on your host machine:

    ==> rpm: Mounting NFS shared folders...
    # ^ Vagrant will hang here


## Intermittent test failures (e.g. timeouts, time-based assertions)

Some tests such as
[ConsumerTimeoutTest](https://github.com/confluentinc/kafka-rest/blob/master/src/test/java/io/confluent/kafkarest/integration/ConsumerTimeoutTest.java)
may experience intermittent failures.  Oftentimes this is caused by slow VM performance when running the test suite
via Vagrant (you will notice that typically the same tests will work fine if you run it directly on your computer).
Apart from tuning CPU, memory, and further Vagrant settings in [Vagrantfile](Vagrantfile), you may also want to
disable any antivirus software and similar applications on your computer while packaging via [package.sh](package.sh).

You can also use the `SKIP_TESTS` configuration in [versions.sh](versions.sh) (see section
[Building, testing, and deploying packages](#deploy) above) to disable the tests during the build process, either
globally or per-project.  But only disable tests if you really know what you are doing!
