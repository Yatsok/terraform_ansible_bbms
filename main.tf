terraform {

  required_providers {

    virtualbox = {

      source = "terra-farm/virtualbox"

      version = "0.2.2-alpha.1"

    }

  }

}


variable "location" {

  type = string

  default = "ssh/insecure_private_key"

}


variable "host_interface" {

  type = string

  default = "wlp1s0"

}


resource "virtualbox_vm" "db" {

  count = 1

  name = "bbms_db"

  image = "https://app.vagrantup.com/ubuntu/boxes/focal64/versions/20240416.0.0/providers/virtualbox/unknown/vagrant.box"

  cpus = 2

  memory = "512 mib"

  network_adapter {

    type = "bridged"

    host_interface = var.host_interface

  }

}


resource "virtualbox_vm" "app" {

  count = 1

  name = "bbms_app"

  image = "https://app.vagrantup.com/ubuntu/boxes/focal64/versions/20240416.0.0/providers/virtualbox/unknown/vagrant.box"

  cpus = 2

  memory = "512 mib"

  network_adapter {

    type = "bridged"

    host_interface = var.host_interface

  }

}


resource "null_resource" "ansible" {

  depends_on = [virtualbox_vm.db, virtualbox_vm.app]

  provisioner "local-exec" {

    environment = {

      IP_APP = element(virtualbox_vm.app.*.network_adapter.0.ipv4_address, 1)

      IP_DB = element(virtualbox_vm.db.*.network_adapter.0.ipv4_address, 1)

      PRIVATE_KEY_PATH = var.location

    }

    interpreter = ["/bin/bash", "-c"]


    command = <<-EOT

              sed "/^$servername/ s/localhost/$IP_DB/" ./roles/conf-nginx/files/config.php > ./roles/conf-nginx/files/connection.php

              ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u vagrant -i $IP_DB, --private-key $PRIVATE_KEY_PATH db-setup.yml

              ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -u vagrant -i $IP_APP, --private-key $PRIVATE_KEY_PATH app-setup.yml

              rm -f ./roles/conf-nginx/files/connection.php

    EOT


  }

}

