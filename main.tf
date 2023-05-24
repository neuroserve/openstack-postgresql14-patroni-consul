locals {
    consul_version="1.15.2"
}

variable "auth_url" {
  type    = string
  default = "https://api.gx-scs.sovereignit.cloud:5000" 
}

variable "user_name" {
  type    = string
  default = "username" 
}

variable "password" {
  type    = string
  default = "totalgeheim" 
}

resource "random_password" "admin_password" {
    length = 32
    special = false
}

#
# This assumes, that you already have a CA - see "consul tls -help" if you don't have one yet
#

resource "tls_private_key" "consul" {
    count = var.config.vm.replicas
    algorithm = "RSA"
    rsa_bits  = "4096"
}

# Create the request to sign the cert with our CA
resource "tls_cert_request" "consul" {
    count = "${var.config.vm.replicas}"
    private_key_pem = "${element(tls_private_key.consul.*.private_key_pem, count.index)}"

    dns_names = [
        "consul",
        "consul.local",
    ]

    subject {
        common_name  = "consul.local"
        organization = var.config.organization.name
    }
}

resource "tls_locally_signed_cert" "consul" {
    count = var.config.vm.replicas
    cert_request_pem = "${element(tls_cert_request.consul.*.cert_request_pem, count.index)}"

    ca_private_key_pem = file("${var.config.private_key_pem}")
    ca_cert_pem        = file("${var.config.certificate_pem}")

    validity_period_hours = 8760

    allowed_uses = [
        "cert_signing",
        "client_auth",
        "digital_signature",
        "key_encipherment",
        "server_auth",
    ]
}

data "openstack_images_image_v2" "os" {
  name        = "postgresql14-patroni-consul"
  visibility = "private"
  most_recent = "true"
}

resource "openstack_compute_keypair_v2" "user_keypair" {
  name       = "tf_postgresql"
  public_key = file("${var.config.keypair}")
}

resource "openstack_networking_secgroup_v2" "sg_patroni" {
  name        = "sg_patroni"
  description = "Security Group for patroni"
}

resource "openstack_networking_secgroup_rule_v2" "sr_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_secgroup_rule_v2" "sr_dns1" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_secgroup_rule_v2" "sr_dns2" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 53
  port_range_max    = 53
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_compute_servergroup_v2" "patronicluster" {
  name = "aaf-sg"
  policies = ["anti-affinity"]
}

resource "openstack_compute_instance_v2" "postgresql" {
  name            = "postgresql-${count.index}"
  image_id        = data.openstack_images_image_v2.os.id
  flavor_name     = var.config.flavor_name
  key_pair        = openstack_compute_keypair_v2.user_keypair.name
  count           = var.config.vm.replicas
  security_groups = ["sg_patroni", "default"]   
  scheduler_hints {
    group = openstack_compute_servergroup_v2.patronicluster.id
  }

  network {
    uuid = var.config.instance_backnet_uuid
  }

  network {
    uuid = var.config.instance_network_uuid
  }
  
  metadata = {
     consul-role = "client"
  }

  connection {
       type = "ssh"
       user = "root" 
       private_key = file("${var.config.connkey}")
       agent = "true" 
       bastion_host = "${var.config.bastionhost}"
       bastion_user = "debian" 
       bastion_private_key = file("${var.config.connkey}")
       host = self.access_ip_v4
  }

  provisioner "remote-exec" {
     inline = [
       "chown consul /etc/consul/certificates",
       "chgrp consul /etc/consul/certificates",
     ]
  }

  provisioner "file" {
     content = file("${var.config.certificate_pem}")
     destination = "/etc/consul/certificates/ca.pem"
  }

  provisioner "file" {
     content = tls_locally_signed_cert.consul[count.index].cert_pem
     destination = "/etc/consul/certificates/cert.pem"
  }

  provisioner "file" {
     content = tls_private_key.consul[count.index].private_key_pem
     destination = "/etc/consul/certificates/private_key.pem"
  }

  provisioner "file" {
     content = file("${path.module}/files/patroni_env.conf")
     destination = "/etc/patroni_env.conf"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/consul.hcl.tpl", {
        datacenter_name = var.config.consul_datacenter_name,
        node_name = "postgresql-${count.index}"
        encryption_key = var.config.consul_encryption_key,
        os_domain_name = var.config.os_domain_name,
        auth_url = "${var.auth_url}",
        user_name = "${var.user_name}",
        password = "${var.password}",
     })
     destination = "/etc/consul/consul.hcl"
  }

  provisioner "remote-exec" {
     inline = [
       "systemctl enable consul",
       "systemctl start consul",
     ]
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/patroni.yml.tpl", {
        hostname = "postgresql-${count.index}"
        consul_addr = var.config.consul_addr
        consul_scope = var.config.consul_scope
        consul_namespace = var.config.consul_namespace
        admin_password = random_password.admin_password.result
        listen_ip = self.access_ip_v4
     })
     destination = "/var/lib/postgresql/patroni.yml"
  }

  provisioner "remote-exec" {
     inline = [
       "chown postgres /var/lib/postgresql/patroni.yml",
       "chgrp postgres /var/lib/postgresql/patroni.yml",

       "systemctl enable patroni",
       "systemctl start patroni",
     ]
  }
}
