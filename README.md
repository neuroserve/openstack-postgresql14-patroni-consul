# Deploy a Postgres Patroni Cluster with multiple nodes on Openstack

This repo uses terraform to deploy a Postgres Patroni Cluster (backed by a Consul Cluster as a DCS) which can be accessed via a loadbalancer instance into an openstack cloud. 

## Prerequisites

1. You need to create the required images first. Try the openstack-packer repo.
2. You need to deploy a bastion host. Try the openstack-bastion-host repo.
3. You need to deploy a Consul cluster. Try the openstack-consul-server repo.
4. If you want to use Percona Monitoring and Management, set up and configure a server. 

## Deployment

Obviously, you have to populate terraform.tfvars according to your environment. terraform.tfvars.sample should give you some hints.
Keep in mind to change `consul_scope` every time you deploy (or delete the contents in consul) - otherwise the patroni cluster will not be able to assemble itself.

Plan and apply by providing the required variables:
`terraform plan -var "auth_url=https://myauthurl.com:5000" -var "user_name=myusername" -var "password=mypassword" -var "user_domain_name=osdomain" -var "tenant_name=osproject" -var "region=osregion"`


