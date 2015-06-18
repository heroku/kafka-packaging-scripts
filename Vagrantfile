# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "deb" do |deb|
    deb.vm.box = "ubuntu/trusty64"
    deb.vm.provision "shell", path: "vagrant/deb.sh"
  end

  config.vm.synced_folder "~/.gnupg", "/root/.gnupg", owner: "root", group: "root"

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2048"]
  end
end
