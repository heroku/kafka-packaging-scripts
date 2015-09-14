# Confluent Packaging

This repository contains scripts to build all the binary packages of the Confluent Platform.

* Builds in clean VMs to ensure reproducible builds.
* Deploys against staging S3 buckets to minimize the risk of production issues.
* Handles inter-project dependencies; e.g. makes sure that kafka-rest's build process has access to a compiled version of
  [rest-utils](https://github.com/confluentinc/rest-utils), even if rest-utils isn't available publicly (via e.g. Central).
* Ties together all the standalone tgz/zip archives into one large distribution.
* Does a basic installation sanity check on the resulting packages.


---

Table of Contents

* <a href="#workflow">Deployment workflow</a>
* <a href="#prerequisites">Prerequisites</a>
* <a href="#deploy">Building, testing, and deploying packages</a>
* <a href="#example-settings">Example settings</a>
* <a href="#add-new">Adding new packages</a>
* <a href="#troubleshooting">Troubleshooting</a>
* <a href="#references">References</a>

---

<a name="workflow">Deployment workflow</a>

# Deployment workflow

This section describes the high level workflow of how to perform a CP release, whether this is a final release
("CP 1.0.0 Release"), a patch/bug fix release ("CP 1.0.1"), or a snapshot release ("CP 1.0.1-SNAPSHOT").

> **Terminology:** A "CP release" means a set of CP components (e.g. kafka-rest, schema-registry, Kafka, Camus)
> including their exact versions.  At the moment, the release number of the CP release is (and must be) identical to the
> release number of the CP components (with the exception of Kafka, which follows its own release naming), and vice
> versa.  For example, CP 1.0.1 Release consists of kafka-rest 1.0.1, schema-registry 1.0.1, Camus 1.0.1, and so on.


## Step 1: Decide the scope of the CP release, create individual releases of CP components

First you must decide which features, bugs, etc. should be part of the CP release (for simplicity we ignore the
question which projects/components should be included in the first place).  This decision is technically
captured by creating a new release of the respective CP projects such as kafka-rest and schema-registry.  With regards
to packaging and deployment the important side-effects of creating these releases are the _git tags_ of the releases
because this is the primary means by which we specify what gets packaged and deployed; e.g. the git tag `v1.2.3` would
label the 1.2.3 release of a project.  Normally we create such git tags in the upstream projects for final releases as
well alpha/beta/rc releases but not for snapshots (for deploying a snapshot release we'd refer to the _git branch_
instead of a git tag).

> **Version lock-step of CP projects**: For technical reasons the current implementation of the packaging scripts
> requires that all CP projects make version updates in lock-step.  So as a consequence of releasing a newer version
> of a CP project, we also need to release new versions of the remaining CP projects.  For further details see section
> _Example workflow: deploying a patch/bug fix release_ below.  It also means that the release number of a CP release
> is (currently) always identical to the release number of the individual CP components (with the exception of Kafka,
> which follows its own release naming).  Removing this lock-step of versions is a desired future improvement that we
> are already tracking.

As an Apache open source project Apache Kafka is slightly different from CP projects because its release process is
managed by the Kafka project.  This means, for example, that we might need to wait until the desired Kafka version is
officially released prior to our own packaging and deployment of said version (unless, for instance, we want to build
and deploy a version of Kafka based on our fork).  But apart from this difference Kafka is handled just like the CP
projects described above:  you must decide which Kafka version you'd like to use (expressed as a Kafka version number
such as `0.8.2.1` and a Kafka branch) as the base for a CP release, and then configure [settings.sh](settings.sh) in
this project accordingly.  Of course it is important that you pick a Kafka version that is actually compatible with the
versions of the CP projects that you include in the CP release.

At this point individual releases of all the CP components including Kafka are available.  Now we can continue with
packaging and deploying these components.


## Step 2: Perform the deployment of the CP release

In the previous step we defined the scope of the CP release and ensured the various CP components are in a
"release-ready" state.  Now we can build and deploy the CP release (cf. section
[Building, testing, and deploying packages](#deploy) below for full details).  At a high level, deploying a release
means we will perform the following steps via the scripts provided in this repository:

1. Configure [settings.sh](settings.sh) to include the desired versions of the CP components (see step 1).
2. Package the respective components (e.g. [kafka-rest](https://github.com/confluentinc/kafka-rest/),
   [schema-registry](https://github.com/confluentinc/schema-registry/) but also Kafka and
   [Camus](https://github.com/confluentinc/camus)) in build VMs for our various target platforms such as Debian.
   This packaging is driven by the configuration in [settings.sh](settings.sh).
3. Run smoke tests to verify the generated packages.
4. Deploy the generated packages to yum/apt/maven/... repositories, which in our case are hosted on AWS/S3.


## Step 3: Handle further release logistics

While we will not describe the various release logistics here, we do want to point out that there is follow-up work
that needs to be done once a CP version is technically deployed and "released" as described above.  Such follow-up
work may include CP documentation (cf. [docs.confluent.io](http://docs.confluent.io/)), announcements, and blog posts,
for instance.


## Example workflow: deploying a patch/bug fix release

Let's say we released CP 1.0, and a few days later we receive a bug report for
[schema-registry](https://github.com/confluentinc/schema-registry/).  As a consequence we decide to release a patch
version, CP 1.0.1, that only includes the bug fix for schema registry.  How would the end-to-end workflow for releasing
CP 1.0.1 look like, i.e. including but not limited to the packaging scripts in this repository?

In short, we'd need to (1) release a 1.0.1 version of schema registry (this work is done in the upstream project);
(2) for technical reasons, we need to release a 1.0.1 for all other CP projects, too (again, this work is done in the
upstream projects); (3) we would then package and deploy the 1.0.1 release (this work is done via the packaging scripts
in this repository).

In more detail:

* First we would fix the bug in schema registry 1.0.  Because this bug fix should be included in the CP 1.0.1 patch
  release, we will create a new 1.0.1 release for schema registry that includes this bug fix.  "Creating a new release"
  of schema registry implies that we would create a git release tag in the schema registry repository (and this git tag
  is required for configuring our packaging scripts).
* In the ideal world this upstream-related work in schema registry would be all we need.  However, at the moment
  releasing a new version of a CP project unfortunately means that we must release new versions of _all_ CP projects
  (common, rest-utils, schema-registry, kafka-rest, camus):  for technical reasons, the current implementation of the
  packaging scripts requires that all CP projects make version updates in lock-step.
  So as a consequence of releasing a newer version of (the now fixed) schema registry, we also need to release
  new 1.0.1 versions of the remaining CP projects.  Thankfully this might be trivial task:  in case the other projects
  (1) haven't changed or (2) they have changed but we would like to not release any such changes as part of the CP
  1.0.1 patch release, we would simply create a new git release tag based on the old, previous release tag for each of
  the remaining CP projects (plus further, project-specific release logistics like updating the changelogs).  Note that
  all the work described in this bullet item would happen in the upstream CP projects. (Also note: Deploying these
  "fake" releases can be done easily thanks to packaging automation but this version lock-step is still inconvenient
  for us and possibly confusing for CP users; hence removing this lock-step of versions is a desired future improvement
  that we are already tracking.)
* Now that the new release 1.0.1 versions of the CP projects including schema registry are ready for deployment, we can
  configure the packaging scripts in this repository accordingly (e.g. by modifying [settings.sh](settings.sh)), and
  then perform the deployment of the CP 1.0.1 patch release.


<a name="prerequisites"></a>

# Prerequisites

## Software packages on host machine

_This section covers Mac OS X only._

You must install the following software packages on your host machine (e.g. your laptop):

* [Vagrant](https://www.vagrantup.com/downloads.html) (1.7+ recommended)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (5.x+ recommended)

You'll also need AWS CLI and Aptly (for deploying artifacts) and `bats`, `dpkg`, `rpm` (for package testing):

```shell
# `brew` is provided by Homebrew (http://brew.sh/)
$ brew install awscli aptly bats dpkg rpm
```

Then you must configure your AWS CLI environment, which particularly includes configuring your AWS credentials (AWS
Access Key and AWS Secret Access Key):

```shell
$ aws configure
```

You will also need your AWS credentials later for configuring [aws.sh](aws.sh).


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
-------------------------------
sec   4096R/41468433 2015-02-06
uid                  Confluent Packaging <packages@confluent.io>
ssb   4096R/F9F8725B 2015-02-06
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


## Step 2: Configure the release process via `settings.sh`

Specify any required build and release settings in [settings.sh](settings.sh), which is sourced into
[package.sh](package.sh):

* `CONFLUENT_VERSION`:  Version of Confluent's tools.  Examples: `1.0.0` (a release), `1.0.1-SNAPSHOT`.
  Note that we do not currently have per-project overrides for `CONFLUENT_VERSION`, so the assumption here is that all
  projects make version updates in lock-step.
* `KAFKA_BRANCH`:  Apache Kafka branch to build (for CP Kafka) and to build against (for CP projects such as
   `kafka-rest`).  Think: `upstream/<BRANCH>`.  Example: `0.8.2`.
* `KAFKA_VERSION`:  The associated Apache Kafka version.  This variable is used mostly for version number parsing in
   the build scripts (as sometimes the version information in the upstream Kafka branches are not matching our
   desired build configuration) as well as for naming the generated package files.  Example: `0.8.2.1`.  (In the future
   we might consider deriving `KAFKA_VERSION` automatically.)
* `SCALA_VERSIONS`:  Space-separated list of Scala versions to use for Scala-dependent projects.  These should just be
  extracted from the Kafka build scripts.  Examples: `2.10.4`, `2.9.1 2.9.2 2.10.4 2.11.5`
* `REVISION`:  Packages go into yum/apt/... repositories organized by `CONFLUENT_VERSION`.  If we need to release any
  updates to packages *with the same version* (cf. `CONFLUENT_VERSION`), the `REVISION` needs to be bumped up so the
  packages go into the same repositories but are treated as updates to the existing packages.
  For example, this would be needed if you made a mistake during the packaging of CP 1.0.0 and now wanted to publish
  fixed CP 1.0.0 packages without bumping the CP version to 1.0.1; in this case, `CONFLUENT_VERSION` would stay at
  `1.0.0` but you would increase `REVISION` from `1` to `2`.  See section *5.6.12 Version* in the
  [Debian Policy Manual](https://www.debian.org/doc/debian-policy/ch-controlfields.html) for further details.
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
* `SIGN_KEY`:  The id or name (e.g. `Confluent Packaging <packages@confluent.io>`) of the GPG key to sign with.  This
  currently *MUST* also be your default key (which will be the case if you have only one secret key) because of
  differences in how RPM and DEB signing work.  You can configure a GPG default key by setting `default-key ABCD1234`
  in your `$HOME/.gnupg/gpg.conf`, where you must replace `ABCD1234` with the id of the actual GPG private key.
  If `SIGN_KEY` is empty, we'll try to fill it in automatically using `gpg --list-secret-keys` but this is quite
  unreliable -- we strongly recommend to explicitly set `SIGN_KEY`.


## Step 3: Run the packaging build

Running the packaging takes care of all projects and package types, based on the configuration you specified in
[settings.sh] (see previous section).  Assuming everything works, you'll find the generated packages in `output/`.

```shell
# For comparison, on a 2015 MacBook Pro 15" (2.5GHz Intel Core i7)
# the packaging of components as of August 2015 takes about one hour.
$ ./package.sh

# See all the generated output files.
$ ls output/
```

Example files for a build with `CONFLUENT_VERSION=1.0.1-SNAPSHOT`, `KAFKA_VERSION=0.8.2.1`, and `REVISION=1`:

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
packages we produce actually work.

The [package_verify.sh](package_verify.sh) script verifies whether the packages were correctly generated, i.e. it will
verify, for example, whether the "Version" and "Release" metadata of an RPM package matches our naming policies, based
on the configuration in [settings.sh](settings.sh).

```shell
# This script runs exclusively on your host machine.
$ ./package_verify.sh
```

The [test.sh](test.sh) script tries to install packages and run some key programs.

```shell
# This script interacts with the build VMs.
$ ./test.sh
```

If something went wrong with the tests, it'll print out a big, obvious error message.


## Step 5: Deploy the packages

_Note: As mentioned below make you sure you have switched to Java 7 for the deploy step._

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

Optionally, you may add a prefix by setting `PACKAGES_BUCKET_PREFIX` and/or `MAVEN_BUCKET_PREFIX` in `aws.sh` if you
don't want to install to the root of the respective buckets -- just make sure it includes the leading `/` (no prefix
is used by default).

Now we will prepare the deployment, which notably includes creating staging S3 buckets.  The contents of these
staging buckets, once tested and verified, will eventually be promoted to corresponding production S3 buckets
(this promotion step is covered and documented elsewhere).

```shell
# Deployment preparation consists of three important tasks:
#
# 1. We prepare the staging S3 buckets for packages and maven artifacts.
# 2. We download any "historical" deb/rpm packages from previous x.y.* releases from S3 and
#    store them under the local output directory.  This is required because, for example,
#    the S3 bucket for CP 1.0.3 should contain all packages for the 1.0.* release line,
#    i.e. 1.0.0, 1.0.1, 1.0.2, 1.0.3.
# 3. We create a timestamped backup of our production S3 bucket for maven artifacts.
#
$ ./deployment_preparation.sh
```

> **S3 bucket management**: The idea is that, for the packages of a given `x.y.*` release line, we create a new S3
> bucket whenever a new `x.y.z` release is deployed.  This new S3 bucket will contain the contents of the new `x.y.z`
> release _including all the contents of any prior releases going back to `x.z.0`_.  This approach ensures that users
> can install `x.y.0`, `x.y.1`, ..., `x.y.z` packages from the same `x.y` indexed yum/apt/... repository.  It also
> enables us to easily rollback a faulty new release by pointing back to the S3 bucket of the previous, working CP
> release.

**Next, make sure you are now switched to Java 7.**
During deployment we re-build to generate the Maven output, but we use the S3 Maven Wagon to deploy, which requires
JRE7.   Where necessary, small patches are applied to ensure the output targets the correct Java 6 compatible version.


> **Java 6 vs. Java 7**:  Future releases of the Confuent Platform will target Java 7.  The Java 6 related instructions
> in this README only apply to CP 1.x builds.

```shell
# On a Mac you can use the `java_home` command:
#
# export JAVA_HOME=`/usr/libexec/java_home -v 1.6` # Java 6
# export JAVA_HOME=`/usr/libexec/java_home -v 1.7` # Java 7
#
$ export JAVA_HOME=/path/to/jdk7
```

Now we can run the deployment scripts, which will deploy the packages and maven artifacts to the staging S3 buckets
we prepared previously.

> **SAFETY NOTE**: None of the deployment scripts will modify production, i.e. all modifying actions are performed
> against staging S3 buckets.  Production data is only ever read from, e.g. to create backups for rollback purposes.
> The steps that do modify production by publishing the staged packages and maven artifacts via S3 and CloudFront
> are covered and documented elsewhere.

You will be prompted multiple times for your GPG key password since some package index files, which are generated
during this deployment step, will need to be signed.

```shell
# Deploy packages (deb, rpm, tar.gz, zip)
$ ./deploy_packages.sh

# Deploy maven artifacts (jars)
# You will be asked (once) for the password of the GPG signing key.
$ ./deploy_artifacts.sh
```

At this point you have built, tested, and deployed the Confluent packages to staging S3 buckets.


## Step 6: Testing and validation of staged packages and maven artifacts

Now you must verify that the packages and maven artifacts in the staging S3 buckets work as expected.

*This step is currently documented elsewhere.*


## Step 7: Publish staging data to production via S3 and CloudFront

**WARNING: This step modifies production and is customer-facing.**

Once you have confirmed that the staged packages and maven artifacts are working as expected you must:

1. Maven: Sync the staging S3 bucket for maven artifacts with the production S3 bucket, modifying the production bucket
   in-place.  (The process above created a timestamped backup of the production bucket in case you must do a rollback).
2. Packages: Update our CloudFront setup via the AWS console so that our users will see the (old plus) new packages and
   artifacts via the official Confluent yum/apt/maven/etc. repositories.  (For rollbacks you can revert the CloudFront
   changes by pointing to the functioning S3 buckets of the previous release.)

*These steps are currently documented elsewhere.*


## Step 8: Terminate the build VMs (clean up)

Finally, clean up the build VMs.  Except for the build output under `output/`, the scripts should be careful to do
everything in temporary space in the VMs so your source tree doesn't get polluted with build by-products.

```shell
# Terminate the VMs
$ vagrant destroy
```


<a name="example-settings"></a>

# Example settings

This section provides examples for configuring [settings.sh](settings.sh).

## Example settings for deploying a final release

The following snippet lists the key settings for deploying a final release.  In this example, we show the settings that
were actually used for deploying the CP 1.0 Release, which is based on Apache Kafka 0.8.2.1.

```bash
### In settings.sh

CONFLUENT_VERSION="1.0" # Note: Future CP releases should also include the patch version (`1.0` -> `1.0.0`)
REVISION="1"
BRANCH="v1.0" # <<< git tag of `v1.0` release

# Apache Kafka
KAFKA_BRANCH="0.8.2"
KAFKA_VERSION="0.8.2.1"
SCALA_VERSIONS="2.9.1 2.9.2 2.10.4 2.11.5"
```

Note how we use a git release tag (here: `v1.0`) as the `BRANCH` to build the CP packages from (i.e. we are not
building from a maintenance or development branch like `origin/1.x`). `CONFLUENT_VERSION` is set to `1.0`, which
indicates a final release (i.e. it is not a snapshot such as `1.0.0-SNAPSHOT` or a beta release).  Apache Kafka has its
own, "special" settings -- one reason is that we must build Kafka against multiple versions of Scala.

When you specify the settings above it is important that the various settings are compatible with each other.  For
instance, the CP packages typically need a specific version of Apache Kafka;  to pick an obviously incorrect example,
you don't want to build CP 1.0 Release based on the very outdated Kafka 0.7 version.


## Example settings for deploying a snapshot

The following snippet lists the key settings for deploying a snapshot release based on the latest code in a maintenance
or development branch.  In this example, we deploy CP 1.0.1-SNAPSHOT, which is based on Apache Kafka 0.8.2.1 and the
`origin/1.x` development branches of the various CP packages (e.g.
[kafka-rest](https://github.com/confluentinc/kafka-rest/)).

```bash
### In settings.sh

CONFLUENT_VERSION="1.0.1-SNAPSHOT"
REVISION="1"
BRANCH="origin/1.x"

# Apache Kafka
KAFKA_BRANCH="0.8.2"
KAFKA_VERSION="0.8.2.1"
SCALA_VERSIONS="2.9.1 2.9.2 2.10.4 2.11.5"
```

When you specify the settings above it is important that the various settings are compatible with each other.  For
instance, the CP packages typically need a specific version of Apache Kafka;  to pick an obviously incorrect example,
you don't want to build CP 1.0.1-SNAPSHOT based on the very outdated Kafka 0.7 version.


## Example settings for re-deploying a final release because of packaging bugs (= revision of a release)

Let's assume that you already released a CP final release, e.g. CP 1.0 Release.  Now you notice that the deployed
packages were generated incorrectly, for example due to a bug in the packaging scripts in this repository.  At this
point you don't want to create a new release such as CP 1.0.1 Release, you'd rather fix the 1.0 Release packages
themselves.  In other words, this situation may happen if the scope of the CP release didn't change but instead we
made a packaging and/or deployment mistake.

In this case you will keep the original release settings as-is but increase the `REVISION` number only.

At the example of the CP 1.0 settings above, here are the settings to deploy a new revision of the same release:

```bash
### In settings.sh

CONFLUENT_VERSION="1.0"
REVISION="2"   # < Only the revision was changed from 1 to 2
BRANCH="v1.0"

# Apache Kafka
KAFKA_BRANCH="0.8.2"
KAFKA_VERSION="0.8.2.1"
SCALA_VERSIONS="2.9.1 2.9.2 2.10.4 2.11.5"
```

The `REVISION` (increased from `1` to `2`) is the only change compared to the original CP 1.0 Release settings.


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
     [settings.sh](settings.sh).
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

You can also use the `SKIP_TESTS` configuration in [settings.sh](settings.sh) (see section
[Building, testing, and deploying packages](#deploy) above) to disable the tests during the build process, either
globally or per-project.  But only disable tests if you really know what you are doing!


## Build fails with "org.bouncycastle.openpgp.PGPException: checksum mismatch at 0 of 20"

The following error indicates that you (1) mistyped your GPG password or (2) you typed the password for the "expected"
GPG key correctly but the packaging setup actually ended up using a different GPG key;  the latter may happen if you
manually configured the wrong GPG key (set via `SIGN_KEY` in `settings.sh`) or if the wrong GPG key was deduced
automatically for you (automatic "key lookup" happens when `SIGN_KEY` is empty and thus was not set by you).

```
:kafka-packaging:core:signArchives
:uploadCoreArchives_2_10_4 FAILED

FAILURE: Build failed with an exception.

* What went wrong:
org.bouncycastle.openpgp.PGPException: checksum mismatch at 0 of 20
> checksum mismatch at 0 of 20

* Try:
Run with --stacktrace option to get the stack trace. Run with --info or --debug option to get more log output.

BUILD FAILED
```


<a name="references"></a>

# References

* [Debian Policy Manual: Chapter 5 - Control files and their fields](https://www.debian.org/doc/debian-policy/ch-controlfields.html),
  notably section _5.6.12 Version_.
* [Fedora Packaging: Naming Guidelines](https://fedoraproject.org/wiki/Packaging:NamingGuidelines),
  notably section _1.4 Package Versioning_.
