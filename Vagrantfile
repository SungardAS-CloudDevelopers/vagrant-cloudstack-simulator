raise "Incorrect Vagrant version" unless Vagrant::VERSION =~ /^1\.5/

timezone = ENV['TZ'] || `sudo systemsetup -gettimezone|cut -d':' -f2`.strip!

Vagrant.configure("2") do |config|
  config.vm.box = "centos-6.5"
  config.vm.box_url = "https://github.com/2creatives/vagrant-centos/releases/download/v6.5.1/centos65-x86_64-20131205.box"

  config.vm.hostname = "vagrant-cloudstack-simulator"
  config.vm.network "private_network", ip: "10.0.123.101"

  config.vm.provider "virtualbox" do |vbox|
    vbox.memory = 4096
  end

  config.vm.provision :shell, :inline => "sudo ln -sf /usr/share/zoneinfo/#{timezone} /etc/localtime"

  config.vm.provision :shell, path: "bootstrap-4.4.sh"
  config.vm.synced_folder ".", "/tmp/cloudstack-simulator"
end
