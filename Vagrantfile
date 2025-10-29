Vagrant.configure("2") do |config|

  config.vm.box = "bento/ubuntu-22.04"
  config.vm.boot_timeout = 300
  
  config.vm.synced_folder ".", "/vagrant", disabled: true
  
  config.vm.define "k8s-master" do |master|
    master.vm.hostname = "k8s-master"
    
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
    
    master.vm.provision "shell", path: "master-2.0.sh", args: ["master"]
  end

  config.vm.define "k8s-worker-1" do |worker1|
    worker1.vm.hostname = "k8s-worker-1"
    
    worker1.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
    
    worker1.vm.provision "shell", path: "provision-worker-1.sh", args: ["worker"]
  end

  config.vm.define "k8s-worker-2" do |worker2|
    worker2.vm.hostname = "k8s-worker-2"
    
    worker2.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = "2"
    end
    
    worker2.vm.provision "shell", path: "provision-worker-2.sh", args: ["worker"]
  end
  
end