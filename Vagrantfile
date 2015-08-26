# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "deb" do |deb|
    deb.vm.box = "ubuntu/trusty64"
    deb.vm.provision "shell", path: "vagrant/deb.sh"
  end

  config.vm.define "rpm" do |rpm|
    rpm.vm.box = "chef/fedora-20"
    rpm.vm.provision "shell", path: "vagrant/rpm.sh"
  end

  config.vm.synced_folder "~/.gnupg", "/root/.gnupg", owner: "root", group: "root"

  config.vm.provider "virtualbox" do |vb|
    # We need 2GB+ memory because some build commands (e.g. for Kafka) run JVMs
    # with 1GB heap space each.
    vb.customize ["modifyvm", :id, "--memory", "3072"]
    vb.customize ["modifyvm", :id, "--cpus", "2"]
  end
end
