locals {
    consul_version="1.15.2"
}

variable "auth_url" {
  type    = string
  default = "https://myauthurl:5000" 
}

variable "user_name" {
  type    = string
  default = "username" 
}

variable "password" {
  type    = string
  default = "totalgeheim" 
}

variable "tenant_name" {
  type    = string
  default = "myproject"
}

variable "user_domain_name" {
  type    = string
  default = "mydomain"
}

variable "region" {
  type   = string
  default = "myregion"
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
  name       = "tf_patroni"
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

resource "openstack_networking_secgroup_rule_v2" "sr_patroni" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8008
  port_range_max    = 8008
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_secgroup_rule_v2" "sr_postgres" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_secgroup_rule_v2" "sr_8300tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8300
  port_range_max    = 8300
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_secgroup_rule_v2" "sr_8300udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 8300
  port_range_max    = 8300
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_secgroup_rule_v2" "sr_8301tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8301
  port_range_max    = 8301
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_secgroup_rule_v2" "sr_8301udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 8301
  port_range_max    = 8301
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_patroni.id
}

resource "openstack_networking_floatingip_v2" "postgres_flip" {
  pool  = "ext01"
}

#resource "openstack_networking_floatingip_associate_v2" "postgres_flip" {
#   floating_ip = "${openstack_networking_floatingip_v2.postgres_flip.address}"
#   port_id = "${openstack_lb_loadbalancer_v2.postgres.vip_port_id}"
#}

resource "openstack_compute_servergroup_v2" "patronicluster" {
  name = "aaf-sg"
  policies = ["anti-affinity"]
}

#resource "openstack_blockstorage_volume_v3" "datavolume" {
#  name  = "pgdatavolume-${count.index}"
#  size  = 500 
#  count = var.config.vm.replicas
#}

#resource "openstack_compute_volume_attach_v2" "dva" {
#  count = var.config.vm.replicas
#  instance_id = "${element(openstack_compute_instance_v2.postgresql.*.id, count.index)}"
#  volume_id = "${element(openstack_blockstorage_volume_v3.datavolume.*.id, count.index)}"
#  device = "/dev/sdb"
#  region = var.config.os_region
#}

resource "openstack_lb_loadbalancer_v2" "postgres" {
  name            = "postgres"
  vip_network_id  = var.config.vipnet_uuid
}

resource "openstack_lb_listener_v2" "postgres" {
  name            = "postgres"
  protocol        = "TCP"
  protocol_port   = 5432
  allowed_cidrs   = var.config.lbaccess 
  loadbalancer_id = openstack_lb_loadbalancer_v2.postgres.id
}

resource "openstack_lb_pool_v2" "postgres" {
  name            = "postgres"
  protocol        = "TCP"
  lb_method       = "ROUND_ROBIN"
  listener_id     = openstack_lb_listener_v2.postgres.id
}

resource "openstack_lb_member_v2" "postgres" {
  count           = var.config.vm.replicas
  name            = "postgresql-${count.index}"
  address         = "${element(openstack_compute_instance_v2.postgresql.*.access_ip_v4, count.index)}"
  protocol_port   = 5432
  pool_id         = openstack_lb_pool_v2.postgres.id
  subnet_id       = var.config.instance_subnet_uuid
  monitor_address = "${element(openstack_compute_instance_v2.postgresql.*.access_ip_v4, count.index)}"
  monitor_port    = 8008
}

resource "openstack_lb_monitor_v2" "postgres" {
  name             = "postgres"
  pool_id          = openstack_lb_pool_v2.postgres.id
  type             = "HTTP"
  delay            = 5
  timeout          = 3
  max_retries      = 3
  url_path         = "/"
  expected_codes   = 200
}

resource "openstack_objectstorage_container_v1" "pg-backup" {
  region = "${var.config.os_region}"
  name   = "pg-backup"
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

#  network {
#    uuid = var.config.instance_backnet_uuid
#  }

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
        os_region   = "${var.config.os_region}",
     })
     destination = "/etc/consul/consul.hcl"
  }

  provisioner "remote-exec" {
     inline = [
       "apt-get -y install xfsprogs",
#       "mkfs.xfs /dev/sdb",
#       "mkdir -p /var/lib/postgresql/data",
#       "mount /dev/sdb /var/lib/postgresql/data",
     ]
  }

  provisioner "remote-exec" {
     inline = [
       "mkdir -p /etc/wal-g.d/env",
     ]
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/AWS_ACCESS_KEY_ID.tpl", {
        access_key = var.config.accesskey,       
     }) 
     destination = "/etc/wal-g.d/env/AWS_ACCESS_KEY_ID"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/AWS_ENDPOINT.tpl", {
        aws_endpoint = var.config.awsendpoint,
     })
     destination = "/etc/wal-g.d/env/AWS_ENDPOINT"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/AWS_REGION.tpl", {
        aws_region = var.config.awsregion,
     })
     destination = "/etc/wal-g.d/env/AWS_REGION"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/AWS_S3_FORCE_PATH_STYLE.tpl", {
        aws_force_path_style = var.config.awsforcepathstyle,
     })
     destination = "/etc/wal-g.d/env/AWS_S3_FORCE_PATH_STYLE"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/AWS_SECRET_ACCESS_KEY.tpl", {
        sec_key = var.config.secretkey,
     })
     destination = "/etc/wal-g.d/env/AWS_SECRET_ACCESS_KEY"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/PGPASSWORD.tpl", {
        pg_password = random_password.admin_password.result,
     })
     destination = "/etc/wal-g.d/env/PGPASSWORD"
  }
  
  provisioner "file" {
     content = templatefile("${path.module}/templates/WALG_COMPRESSION_METHOD.tpl", {
        walg_compress = var.config.walgcompress,
     })
     destination = "/etc/wal-g.d/env/WALG_COMPRESSION_METHOD"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/WALG_S3_PREFIX.tpl", {
        walg_s3_prefix = var.config.walgs3prefix,
     })
     destination = "/etc/wal-g.d/env/WALG_S3_PREFIX"
  }

  provisioner "file" {
     content = templatefile("${path.module}/templates/WAL_S3_BUCKET.tpl", {
        wal_s3_bucket = var.config.wals3bucket,
     })
     destination = "/etc/wal-g.d/env/WAL_S3_BUCKET"
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

  provisioner "remote-exec" {
     inline = [
       "/usr/bin/pmm-admin config --server-insecure-tls --force --server-url=https://admin:${var.config.pmmpasswd}@${var.config.pmmip}:443",
     ]
  }

  provisioner "remote-exec" {
     inline = [
       "/usr/bin/pmm-admin add external-serverless --host=${self.access_ip_v4} --listen-port=8008 --external-name=patroni-node${count.index}", 
     ]
  }

}
