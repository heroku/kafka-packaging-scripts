This directory contains build scripts for each type of package. They get copied
into the VM and executed from there, so they should each be one-off scripts
without any extra dependencies. All system packages they need should have
already been installed by the Vagrant provisioning scripts (vagrant/*.sh).
All final packaging outputs should be saved to the output/ directory.

Generally these scripts should attempt to keep the working space in this
repository clean, i.e. they should use a different working directory for running
their build (possibly re-cloning the repository if that's the easiest way to get
the build running).
