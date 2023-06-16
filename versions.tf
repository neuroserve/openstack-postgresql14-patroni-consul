terraform {
required_version = ">= 1.2.4"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
  }
}

provider "openstack" {
   auth_url = var.auth_url
   cloud = var.config.os_cloud_name
   user_name = var.user_name
   password = var.password
   user_domain_name = var.config.os_domain
   tenant_name = var.config.os_project
   region =  var.config.os_region
}

