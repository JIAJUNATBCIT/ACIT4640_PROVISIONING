Vagrant.configure("2") do |config|
  config.vm.box = "4640BOX"

  config.ssh.username = "admin"
  config.ssh.private_key_path = "./ansible/files/acit_admin_id_rsa"

  config.vm.synced_folder "./shared", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |vb|
      vb.gui = true
      vb.linked_clone = true
  end

  config.vm.provision "file", source: "./ansible", destination: "/home/admin/ansible"

  config.vm.define "db" do |db|
      db.vm.provider "virtualbox" do |vb|
          vb.name = "TODO_DB_4640"
          vb.memory = 2048
      end
      db.vm.hostname = "tododb.bcit.local"
      db.vm.network "private_network", "ip": "192.168.150.30"
      db.vm.provision "ansible_local" do |ansible|
          ansible.provisioning_path = "/home/admin/ansible"
          ansible.playbook = "/home/admin/ansible/db.yaml"
      end
  end

  config.vm.define "nginx" do |nginx|
    nginx.vm.provider "virtualbox" do |vb|
        vb.name = "TODO_NGINX_4640"
        vb.memory = 2048
    end
    nginx.vm.hostname = "todonginx.bcit.local"
    nginx.vm.network "forwarded_port", guest: 80, host: 9880
    nginx.vm.network "private_network", "ip": "192.168.150.10"
    nginx.vm.provision "ansible_local" do |ansible|
        ansible.provisioning_path = "/home/admin/ansible"
        ansible.playbook = "/home/admin/ansible/nginx.yaml"
    end
  end

  config.vm.define "app" do |app|
    app.vm.provider "virtualbox" do |vb|
        vb.name = "TODO_APP_4640"
        vb.memory = 2048
    end
    app.vm.hostname = "todoapp.bcit.local"
    app.vm.network "private_network", "ip": "192.168.150.20"
    app.vm.provision "ansible_local" do |ansible|
        ansible.provisioning_path = "/home/admin/ansible"
        ansible.playbook = "/home/admin/ansible/app.yaml"
    end
  end
end