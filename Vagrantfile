# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "deb" do |deb|
    deb.vm.box = "ubuntu/trusty64"
    deb.vm.provision "shell", path: "vagrant/deb.sh"
    # NFS has better synced folder performance than Vagrant's default.
    # - This requires Mac OS X or Linux on the host machine.
    # - The host must have nfs-kernel-server or nfsd installed (default on Mac OS X).
    # - Newer Ubuntu and Debian systems dont support NFS version 3, if that's
    #   the case remove 'vers=3' from the mount_options below.
    # - The guest machine must have NFS support installed.
    # http://docs.vagrantup.com/v2/synced-folders/nfs.html and
    # http://auramo.github.io/2014/12/vagrant-performance-tuning/
    deb.vm.synced_folder ".", "/vagrant",
        :nfs => true,
        # We cannot use NFSv4 because it is not supported on Mac OS X yet
        # (at least as of OS X Yosemite aka 10.10), and we still need to run
        # these VMs / this code project on Mac OS X.
        :mount_options => ['nolock,vers=3,tcp,noatime,clientaddr=10.20.30.11']
    deb.vm.network "private_network", ip: "10.20.30.11"
  end

  config.vm.synced_folder "~/.gnupg", "/root/.gnupg", owner: "root", group: "root"

  config.vm.provider "virtualbox" do |vb|
    # We need 2GB+ memory because some build commands (e.g. for Kafka) run JVMs
    # with 1GB heap space each.
    vb.customize ["modifyvm", :id, "--memory", "3072"]
    vb.customize ["modifyvm", :id, "--cpus", "2"]

    ### Improve network speed for Internet access.
    # Setting 1: Use a paravirtualized network adapter (virtio-net)
    # http://superuser.com/a/850389/278185 and
    # http://auramo.github.io/2014/12/vagrant-performance-tuning/
    vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
    vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
    # Setting 2: Use NAT'd DNS
    # http://serverfault.com/a/595010 and
    # https://github.com/mitchellh/vagrant/issues/1807
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    # Setting 3: Disable DNS proxy
    # http://serverfault.com/questions/495914#comment801426_595010
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
  end
end
