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

    # Finally, clean up the VMs. Except for the build output, the scripts should
    # be careful to do everything in temporary space in the VM so your source
    # tree doesn't get polluted with build by-products.
    $ vagrant destroy
